require "test_helper"

class SaleTest < ActiveSupport::TestCase
  setup do
    scenario  = full_scenario
    @company  = scenario[:company]
    @store    = scenario[:store]
    @user     = scenario[:user]
    @product  = create_product(@company)
    stock!(product: @product, store: @store, user: @user, quantity: 100)
  end

  # ─── Desglose tributario ────────────────────────────────────────────────────

  test "deriva el neto del bruto y obtiene el IVA por resta" do
    sale = create_sale(company: @company, user: @user, product: @product, unit_price: 11_900)

    assert_equal 10_000, sale.net_amount.to_i
    assert_equal 1_900, sale.tax_amount.to_i
    assert_equal 11_900, sale.total_amount.to_i
  end

  test "neto mas IVA mas exento siempre cuadra con el total" do
    # Montos elegidos para que la division no sea exacta.
    [1, 7, 999, 1_234, 45_679].each do |price|
      sale = create_sale(company: @company, user: @user, product: @product, unit_price: price)
      suma = sale.net_amount + sale.tax_amount + sale.exempt_amount

      assert_equal sale.total_amount, suma, "no cuadra con precio #{price}"
    end
  end

  test "separa las lineas exentas del monto afecto" do
    exento = create_product(@company, name: "Exento", tax_exempt: true)
    stock!(product: exento, store: @store, user: @user, quantity: 10)

    sale = Sales::Creator.new(user: @user, company: @company, params: {
      document_type: "boleta", status: "completed",
      items: [
        { product_id: @product.id, quantity: 2, unit_price: 5_950 },
        { product_id: exento.id, quantity: 1, unit_price: 1_000 }
      ]
    }).call

    assert_equal 10_000, sale.net_amount.to_i
    assert_equal 1_900, sale.tax_amount.to_i
    assert_equal 1_000, sale.exempt_amount.to_i
    assert_equal 12_900, sale.total_amount.to_i
  end

  # ─── Validaciones del receptor ──────────────────────────────────────────────

  test "una factura exige receptor" do
    sale = Sale.new(store: @store, user: @user, document_type: "factura", sold_on: Date.current)

    assert_not sale.valid?
    assert_includes sale.errors[:customer].join, "obligatorio para una factura"
  end

  test "una factura exige RUT y comuna del receptor" do
    sin_datos = @company.customers.create!(name: "Sin datos")

    sale = Sale.new(store: @store, user: @user, document_type: "factura",
                    sold_on: Date.current, customer: sin_datos)
    sale.valid?

    assert_includes sale.errors[:customer].join, "RUT"
    assert_includes sale.errors[:customer].join, "comuna"
  end

  test "una boleta no exige receptor" do
    assert create_sale(company: @company, user: @user, product: @product).persisted?
  end

  # ─── Emision e inmutabilidad ────────────────────────────────────────────────

  test "emitir asigna folio y deja el documento en cola" do
    sale = create_sale(company: @company, user: @user, product: @product)
    assert_not sale.issued?

    sale.issue!

    assert sale.reload.issued?
    assert_equal 1, sale.folio
    assert_equal "queued", sale.sii_status
  end

  test "un documento emitido no admite cambios" do
    sale = create_sale(company: @company, user: @user, product: @product, issue: true)

    error = assert_raises(Sale::Immutable) { sale.update!(notes: "editado") }
    assert_includes error.message, "ya fue emitido"
  end

  test "un documento emitido no admite cambios en sus lineas" do
    sale = create_sale(company: @company, user: @user, product: @product, issue: true)

    assert_raises(Sale::Immutable) { sale.sale_items.first.update!(quantity: 99) }
  end

  test "un documento emitido si puede avanzar su estado ante el SII" do
    sale = create_sale(company: @company, user: @user, product: @product, issue: true)

    sale.reload.update!(sii_status: "accepted", sii_track_id: "TRK-1")

    assert_equal "accepted", sale.reload.sii_status
  end

  test "no se puede emitir dos veces" do
    sale = create_sale(company: @company, user: @user, product: @product, issue: true)

    assert_raises(Sale::Immutable) { sale.issue! }
  end

  # ─── Ingreso neto ───────────────────────────────────────────────────────────

  test "el ingreso neto excluye anuladas y descuenta notas de credito" do
    v1 = create_sale(company: @company, user: @user, product: @product, unit_price: 10_000, issue: true)
    v2 = create_sale(company: @company, user: @user, product: @product, unit_price: 5_000, issue: true)
    scope = -> { Sale.where(id: [v1.id, v2.id] + Sale.where(references_sale_id: [v1.id, v2.id]).ids) }

    assert_equal 15_000.0, Sale.net_revenue(scope.call)

    Sales::CreditNoteCreator.new(sale: v2, user: @user).call

    # La suma cruda contaria la nota de credito como ingreso: 15000 + 5000.
    assert_equal 20_000.0, scope.call.completed.sum(:total_amount).to_f
    assert_equal 10_000.0, Sale.net_revenue(scope.call)
  end

  test "una nota de credito parcial si se descuenta del ingreso" do
    venta = create_sale(company: @company, user: @user, product: @product,
                        quantity: 10, unit_price: 1_000, issue: true)
    scope = -> { Sale.where(id: [venta.id] + Sale.where(references_sale_id: venta.id).ids) }

    assert_equal 10_000.0, Sale.net_revenue(scope.call)

    Sales::CreditNoteCreator.new(sale: venta, user: @user, params: {
      items: [{ product_id: @product.id, quantity: 2 }]
    }).call

    assert_equal 8_000.0, Sale.net_revenue(scope.call)
    assert_not venta.reload.annulled?
  end
end
