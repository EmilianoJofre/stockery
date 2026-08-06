class InventoryManager
  class Error < StandardError; end

  # El stock real vive en `inventory_lots.quantity_remaining`. `inventory_levels`
  # es un cache derivado que se recalcula en cada movimiento, e `inventory_movements`
  # es el ledger append-only que explica como se llego a ese saldo.
  #
  # Toda entrada crea un lote; toda salida consume lotes en orden FEFO.

  # ─── Entrada de stock ───────────────────────────────────────────────────────
  def self.receive!(product:, store:, user:, quantity:, unit_cost: 0, expiry_date: nil,
                    lot_code: nil, received_on: nil, reason: "purchase",
                    source: nil, purchase_item: nil, note: nil)
    quantity = quantity.to_i
    raise Error, "La cantidad a recibir debe ser mayor que cero" unless quantity.positive?

    ActiveRecord::Base.transaction do
      lot = InventoryLot.create!(
        company:           product.company,
        product:           product,
        store:             store,
        purchase_item:     purchase_item,
        lot_code:          lot_code.presence,
        expiry_date:       expiry_date.presence,
        received_on:       received_on.presence || Date.current,
        unit_cost:         unit_cost || 0,
        quantity_received: quantity,
        quantity_remaining: quantity
      )

      InventoryMovement.create!(
        product:         product,
        store:           store,
        user:            user,
        inventory_lot:   lot,
        source:          source,
        quantity_change: quantity,
        unit_cost:       lot.unit_cost,
        reason:          reason,
        note:            note
      )

      refresh_level!(product: product, store: store)
    end
  end

  # ─── Salida de stock (FEFO) ─────────────────────────────────────────────────
  # Una salida puede abarcar varios lotes: se genera un movimiento por cada lote
  # tocado, de modo que el ledger conserve de que lote salio cada unidad.
  def self.issue!(product:, store:, user:, quantity:, reason: "sale", source: nil, note: nil)
    quantity = quantity.to_i
    raise Error, "La cantidad a descontar debe ser mayor que cero" unless quantity.positive?

    ActiveRecord::Base.transaction do
      # FOR UPDATE sobre los lotes disponibles: dos ventas simultaneas del mismo
      # producto se serializan aqui en vez de competir por el saldo agregado.
      lots = InventoryLot.where(product: product, store: store).available.fefo.lock.to_a
      available = lots.sum(&:quantity_remaining)

      if available < quantity
        raise Error, "Stock insuficiente de #{product.name} en #{store.name} " \
                     "(disponible: #{available}, requerido: #{quantity})"
      end

      pending = quantity
      lots.each do |lot|
        break unless pending.positive?

        taken = [lot.quantity_remaining, pending].min
        lot.update!(quantity_remaining: lot.quantity_remaining - taken)

        InventoryMovement.create!(
          product:         product,
          store:           store,
          user:            user,
          inventory_lot:   lot,
          source:          source,
          quantity_change: -taken,
          unit_cost:       lot.unit_cost,
          reason:          reason,
          note:            note
        )

        pending -= taken
      end

      refresh_level!(product: product, store: store)
    end
  end

  # ─── Ajuste manual ──────────────────────────────────────────────────────────
  # Mantiene la firma previa para no romper el endpoint de ajustes ni las seeds.
  # Un ajuste positivo crea un lote; uno negativo consume en orden FEFO.
  def self.adjust!(product:, store:, user:, quantity_change:, reason:, note: nil,
                   expiry_date: nil, lot_code: nil, unit_cost: nil, source: nil)
    quantity_change = quantity_change.to_i
    raise Error, "El ajuste de inventario no puede ser cero" if quantity_change.zero?

    if quantity_change.positive?
      receive!(
        product: product, store: store, user: user,
        quantity: quantity_change,
        unit_cost: unit_cost || fallback_unit_cost(product: product, store: store),
        expiry_date: expiry_date, lot_code: lot_code,
        reason: reason, source: source, note: note
      )
    else
      issue!(
        product: product, store: store, user: user,
        quantity: -quantity_change,
        reason: reason, source: source, note: note
      )
    end
  end

  # ─── Devolucion a los lotes de origen ───────────────────────────────────────
  # Devuelve stock al lote EXACTO del que salio, en vez de crear un lote nuevo.
  # Esto solo es posible porque cada movimiento guarda su `inventory_lot_id`:
  # asi la mercaderia devuelta conserva su vencimiento real y no reaparece como
  # si fuera fresca.
  #
  # Se recorre en orden inverso al consumo (lo ultimo que salio vuelve primero).
  def self.restore_from_document!(document:, product:, store:, user:, quantity:,
                                  reason: "sale", source: nil, note: nil)
    quantity = quantity.to_i
    raise Error, "La cantidad a devolver debe ser mayor que cero" unless quantity.positive?

    ActiveRecord::Base.transaction do
      pending = quantity

      consumed_by_lot(document: document, product: product, store: store).each do |lot_id, net_taken|
        break unless pending.positive?
        next unless net_taken.positive?

        lot = InventoryLot.lock.find(lot_id)
        giving_back = [net_taken, pending].min

        lot.update!(quantity_remaining: lot.quantity_remaining + giving_back)

        InventoryMovement.create!(
          product: product, store: store, user: user,
          inventory_lot: lot, source: source,
          quantity_change: giving_back,
          unit_cost: lot.unit_cost,
          reason: reason, note: note
        )

        pending -= giving_back
      end

      if pending.positive?
        raise Error, "No se puede devolver #{quantity} de #{product.name}: el documento " \
                     "original solo tiene #{quantity - pending} unidades pendientes de devolucion"
      end

      refresh_level!(product: product, store: store)
    end
  end

  # Neto pendiente de devolucion por lote: lo que salio por el documento menos
  # lo ya devuelto por sus notas de credito. Se agrupa sobre el ledger, que es
  # la unica fuente confiable de que unidad salio de que lote.
  #
  # El orden es el inverso al del consumo (`MAX(id) DESC`): lo ultimo que salio
  # es lo primero que vuelve, que es lo que corresponde al deshacer una venta.
  def self.consumed_by_lot(document:, product:, store:)
    sources = [document] + Array(document.try(:credit_notes))

    scope = InventoryMovement
      .where(product: product, store: store)
      .where(source: sources)
      .where.not(inventory_lot_id: nil)
      .group(:inventory_lot_id)

    net_by_lot = scope.sum(:quantity_change).transform_values { |net| -net }
    last_touch = scope.maximum(:id)

    net_by_lot
      .sort_by { |lot_id, _net| -last_touch.fetch(lot_id, 0) }
      .to_h
  end
  private_class_method :consumed_by_lot

  # Recalcula el cache de saldo desde los lotes, la unica fuente de verdad.
  def self.refresh_level!(product:, store:)
    total = InventoryLot.where(product: product, store: store).sum(:quantity_remaining)

    level = InventoryLevel.find_or_initialize_by(product: product, store: store)
    level.quantity = total
    level.save!
    level
  end

  # Costo de referencia para entradas sin costo explicito (ajustes manuales):
  # el del ultimo lote con saldo, para no valorizar en cero una reposicion.
  def self.fallback_unit_cost(product:, store:)
    InventoryLot.where(product: product, store: store)
      .available
      .order(received_on: :desc, id: :desc)
      .limit(1)
      .pick(:unit_cost) || 0
  end
  private_class_method :fallback_unit_cost
end
