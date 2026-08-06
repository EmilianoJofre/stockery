module Sales
  # Emite una nota de credito sobre una venta ya emitida.
  #
  # Es el UNICO mecanismo de correccion: un DTE emitido es inmutable, asi que
  # equivocarse no se arregla editando sino emitiendo el documento inverso.
  #
  # Acepta devolucion total (sin `items`) o parcial (con las lineas devueltas).
  # En ambos casos el stock vuelve al lote exacto del que salio, conservando su
  # vencimiento real.
  class CreditNoteCreator
    def initialize(sale:, user:, params: {})
      @sale = sale
      @user = user
      @company = sale.store.company
      @params = params.deep_symbolize_keys
    end

    def call
      validate_source!

      Sale.transaction do
        lines = resolve_lines!
        # Se evalua UNA sola vez, antes de persistir la nota: una vez que sus
        # lineas existen, `pending_quantity` ya las descuenta y la respuesta
        # cambiaria.
        full_return = full_return?(lines)

        note = Sale.new(
          store:           sale.store,
          user:            @user,
          document_type:   "nota_credito",
          status:          "completed",
          sold_on:         Date.current,
          customer:        sale.customer,
          customer_name:   sale.customer_name,
          references_sale: sale,
          reference_code:  full_return ? Sale::REFERENCE_CODES[:annul] : Sale::REFERENCE_CODES[:fix_amounts],
          reference_reason: @params[:reason].presence || "Anulacion de #{sale.reference}",
          notes:           @params[:notes]
        )

        lines.each do |line|
          note.sale_items.build(
            product:    line[:item].product,
            quantity:   line[:quantity],
            unit_price: line[:item].unit_price,
            tax_exempt: line[:item].tax_exempt
          )
        end

        note.save!
        restore_inventory!(note, lines)

        # Solo una devolucion total anula el documento original.
        sale.update_columns(annulled_at: Time.current, updated_at: Time.current) if full_return

        note.issue! if truthy?(@params.fetch(:issue, true))
        note
      end
    end

    private

    attr_reader :sale, :company

    def validate_source!
      raise InventoryManager::Error, "Solo se puede anular un documento emitido" unless sale.issued?
      raise InventoryManager::Error, "#{sale.reference} ya fue anulado" if sale.annulled?
      raise InventoryManager::Error, "Una nota de credito no se corrige con otra" if sale.credit_note?
    end

    # Sin `items` se devuelve todo lo que quede pendiente.
    def resolve_lines!
      requested = Array(@params[:items])
      return full_lines if requested.empty?

      requested.filter_map do |entry|
        item = sale.sale_items.find { |i| i.product_id.to_s == entry[:product_id].to_s }
        raise InventoryManager::Error, "El producto no pertenece a #{sale.reference}" if item.nil?

        quantity = entry[:quantity].to_i
        next if quantity.zero?

        available = pending_quantity(item)
        if quantity > available
          raise InventoryManager::Error,
                "No se puede devolver #{quantity} de #{item.product.name}: " \
                "quedan #{available} unidades por devolver"
        end

        { item: item, quantity: quantity }
      end.tap do |lines|
        raise InventoryManager::Error, "Debes indicar al menos una linea a devolver" if lines.empty?
      end
    end

    def full_lines
      sale.sale_items.filter_map do |item|
        pending = pending_quantity(item)
        next if pending.zero?

        { item: item, quantity: pending }
      end.tap do |lines|
        raise InventoryManager::Error, "#{sale.reference} ya fue devuelto por completo" if lines.empty?
      end
    end

    # Lo vendido menos lo ya devuelto por notas de credito anteriores.
    def pending_quantity(item)
      returned = SaleItem
        .joins(:sale)
        .where(sales: { references_sale_id: sale.id }, product_id: item.product_id)
        .sum(:quantity)

      item.quantity - returned
    end

    def full_return?(lines)
      sale.sale_items.all? do |item|
        line = lines.find { |l| l[:item].id == item.id }
        line.present? && line[:quantity] == pending_quantity(item)
      end
    end

    # La devolucion solo repone stock si la venta lo habia descontado.
    def restore_inventory!(note, lines)
      return unless sale.completed?

      lines.each do |line|
        InventoryManager.restore_from_document!(
          document: sale,
          product:  line[:item].product,
          store:    sale.store,
          user:     @user,
          quantity: line[:quantity],
          reason:   "sale",
          source:   note,
          note:     "Devuelto por #{note.reference} (anula #{sale.reference})"
        )
      end
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value) != false
    end
  end
end
