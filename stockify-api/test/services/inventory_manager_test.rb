require "test_helper"

class InventoryManagerTest < ActiveSupport::TestCase
  setup do
    @company = create_company
    @store   = create_store(@company)
    @user    = create_user(@company)
    @product = create_product(@company)
  end

  def lots
    InventoryLot.where(product: @product, store: @store)
  end

  def level
    InventoryLevel.find_by(product: @product, store: @store)
  end

  # ─── Entrada ────────────────────────────────────────────────────────────────

  test "recibir crea un lote y actualiza el saldo" do
    InventoryManager.receive!(product: @product, store: @store, user: @user,
                              quantity: 10, unit_cost: 500, lot_code: "L-1")

    lot = lots.sole
    assert_equal 10, lot.quantity_received
    assert_equal 10, lot.quantity_remaining
    assert_equal 500, lot.unit_cost.to_i
    assert_equal 10, level.quantity
  end

  test "recibir registra un movimiento de entrada" do
    InventoryManager.receive!(product: @product, store: @store, user: @user, quantity: 10)

    movement = InventoryMovement.where(product: @product).sole
    assert_equal 10, movement.quantity_change
    assert movement.inbound?
  end

  test "no se puede recibir una cantidad no positiva" do
    assert_raises(InventoryManager::Error) do
      InventoryManager.receive!(product: @product, store: @store, user: @user, quantity: 0)
    end
  end

  # ─── Salida FEFO ────────────────────────────────────────────────────────────

  test "consume primero el lote que vence antes, no el que llego antes" do
    stock!(product: @product, store: @store, user: @user, quantity: 10,
           unit_cost: 100, expiry_date: Date.current + 30, lot_code: "TARDE")
    stock!(product: @product, store: @store, user: @user, quantity: 5,
           unit_cost: 110, expiry_date: Date.current + 5, lot_code: "PRONTO")
    stock!(product: @product, store: @store, user: @user, quantity: 7,
           unit_cost: 120, expiry_date: nil, lot_code: "SIN-VENC")

    assert_equal %w[PRONTO TARDE SIN-VENC], lots.available.fefo.pluck(:lot_code)

    InventoryManager.issue!(product: @product, store: @store, user: @user, quantity: 8)

    assert_equal 0, lots.find_by(lot_code: "PRONTO").quantity_remaining
    assert_equal 7, lots.find_by(lot_code: "TARDE").quantity_remaining
    assert_equal 7, lots.find_by(lot_code: "SIN-VENC").quantity_remaining
    assert_equal 14, level.quantity
  end

  test "una salida que cruza lotes genera un movimiento por lote con su costo" do
    stock!(product: @product, store: @store, user: @user, quantity: 5,
           unit_cost: 110, expiry_date: Date.current + 5, lot_code: "PRONTO")
    stock!(product: @product, store: @store, user: @user, quantity: 10,
           unit_cost: 100, expiry_date: Date.current + 30, lot_code: "TARDE")

    InventoryManager.issue!(product: @product, store: @store, user: @user, quantity: 8)

    salidas = InventoryMovement.where(product: @product).outbound.order(:id)
    assert_equal 2, salidas.size
    assert_equal [-5, -3], salidas.map(&:quantity_change)
    # Costo distinto por lote: es lo que permite valorizar FIFO real.
    assert_equal [110, 100], salidas.map { |m| m.unit_cost.to_i }
  end

  test "falla si no hay stock suficiente" do
    stock!(product: @product, store: @store, user: @user, quantity: 3)

    error = assert_raises(InventoryManager::Error) do
      InventoryManager.issue!(product: @product, store: @store, user: @user, quantity: 10)
    end
    assert_includes error.message, "Stock insuficiente"
    assert_equal 3, level.quantity, "un fallo no debe alterar el saldo"
  end

  # ─── Ajustes ────────────────────────────────────────────────────────────────

  test "un ajuste negativo consume en orden FEFO" do
    stock!(product: @product, store: @store, user: @user, quantity: 5,
           expiry_date: Date.current + 3, lot_code: "PRONTO")
    stock!(product: @product, store: @store, user: @user, quantity: 5,
           expiry_date: Date.current + 90, lot_code: "TARDE")

    InventoryManager.adjust!(product: @product, store: @store, user: @user,
                             quantity_change: -6, reason: "damage")

    assert_equal 0, lots.find_by(lot_code: "PRONTO").quantity_remaining
    assert_equal 4, lots.find_by(lot_code: "TARDE").quantity_remaining
  end

  test "un ajuste positivo crea un lote nuevo" do
    InventoryManager.adjust!(product: @product, store: @store, user: @user,
                             quantity_change: 5, reason: "restock")

    assert_equal 1, lots.count
    assert_equal 5, level.quantity
  end

  test "un ajuste de cero es invalido" do
    assert_raises(InventoryManager::Error) do
      InventoryManager.adjust!(product: @product, store: @store, user: @user,
                               quantity_change: 0, reason: "audit")
    end
  end

  # ─── Invariante del cache ───────────────────────────────────────────────────

  test "el saldo cacheado siempre iguala la suma de los lotes" do
    stock!(product: @product, store: @store, user: @user, quantity: 10)
    stock!(product: @product, store: @store, user: @user, quantity: 5)
    InventoryManager.issue!(product: @product, store: @store, user: @user, quantity: 7)
    InventoryManager.adjust!(product: @product, store: @store, user: @user,
                             quantity_change: 3, reason: "restock")

    assert_equal lots.sum(:quantity_remaining), level.quantity
  end

  # ─── Devolucion al lote de origen ───────────────────────────────────────────

  test "la devolucion vuelve al lote exacto, conservando su vencimiento" do
    stock!(product: @product, store: @store, user: @user, quantity: 5,
           unit_cost: 100, expiry_date: Date.current + 5, lot_code: "PRONTO")
    stock!(product: @product, store: @store, user: @user, quantity: 10,
           unit_cost: 200, expiry_date: Date.current + 60, lot_code: "TARDE")

    scenario = full_scenario
    # Se reutiliza la compania del escenario para poder emitir.
    sale = Sales::Creator.new(user: @user, company: @company, params: {
      document_type: "boleta", status: "completed",
      items: [{ product_id: @product.id, quantity: 8, unit_price: 1_000 }]
    }).call

    assert_equal 7, level.quantity

    InventoryManager.restore_from_document!(
      document: sale, product: @product, store: @store,
      user: @user, quantity: 8, source: sale
    )

    assert_equal 5, lots.find_by(lot_code: "PRONTO").quantity_remaining,
                 "el lote por vencer debe recuperar sus unidades"
    assert_equal 10, lots.find_by(lot_code: "TARDE").quantity_remaining
    assert_equal 15, level.reload.quantity
  end

  test "no se puede devolver mas de lo que salio por el documento" do
    stock!(product: @product, store: @store, user: @user, quantity: 10)
    sale = Sales::Creator.new(user: @user, company: @company, params: {
      document_type: "boleta", status: "completed",
      items: [{ product_id: @product.id, quantity: 3, unit_price: 1_000 }]
    }).call

    assert_raises(InventoryManager::Error) do
      InventoryManager.restore_from_document!(
        document: sale, product: @product, store: @store,
        user: @user, quantity: 99, source: sale
      )
    end
  end
end
