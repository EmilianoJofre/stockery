module Sales
  class Creator
    def initialize(user:, params:, company: nil)
      @user = user
      @company = company || user.company
      @params = params.deep_symbolize_keys
    end

    def call
      Sale.transaction do
        sale = Sale.new(
          store:         resolve_store!,
          status:        normalized_status,
          document_type: normalized_document_type,
          reference:     @params[:reference],
          sold_on:       @params[:sold_on].presence || Date.current,
          customer:      resolve_customer!,
          customer_name: @params[:customer_name],
          notes:         @params[:notes],
          user:          @user
        )

        build_items(sale)
        sale.save!
        commit_inventory!(sale) if sale.completed?
        # La emision (folio + inmutabilidad) es un paso explicito: se puede
        # registrar la venta sin emitir todavia el DTE.
        sale.issue! if truthy?(@params[:issue])
        sale
      end
    end

    private

    def resolve_store!
      store_id = @params[:store_id].presence
      if store_id
        @company.stores.find(store_id)
      elsif (default = @company.default_store)
        default
      else
        raise InventoryManager::Error, "La compañía no tiene ninguna tienda activa"
      end
    end

    def build_items(sale)
      items = Array(@params[:items])
      raise InventoryManager::Error, "Debes agregar al menos una linea de venta" if items.empty?

      items.each do |item|
        product = @company.products.find(item[:product_id])

        sale.sale_items.build(
          product:    product,
          quantity:   item[:quantity],
          unit_price: item[:unit_price].presence || product.price,
          # Se fija aca y no en un callback de SaleItem porque el calculo de
          # montos del Sale corre en su before_validation, es decir ANTES de los
          # callbacks de las lineas: si no, el desglose veria todo como gravado.
          tax_exempt: product.tax_exempt
        )
      end
    end

    def commit_inventory!(sale)
      sale.sale_items.each do |item|
        InventoryManager.issue!(
          product:  item.product,
          store:    sale.store,
          user:     @user,
          quantity: item.quantity,
          reason:   "sale",
          source:   sale,
          note:     "Vendido por #{sale.reference}"
        )
      end
    end

    def normalized_status
      status = @params[:status].to_s
      return status if Sale.statuses.key?(status)
      "completed"
    end

    # Acepta el nombre ("boleta") o el codigo del SII (39). Por defecto boleta,
    # que es lo habitual en retail de mostrador.
    def normalized_document_type
      raw = @params[:document_type]
      return "boleta" if raw.blank?

      name = raw.to_s
      return name if Sale.document_types.key?(name)

      Sale.document_types.key(raw.to_i) || "boleta"
    end

    # Busca el cliente por id, o por RUT creandolo si no existe: en el mostrador
    # el RUT se pide recien al emitir una factura.
    def resolve_customer!
      if @params[:customer_id].present?
        return @company.customers.find(@params[:customer_id])
      end

      rut = @params[:customer_rut]
      return nil if rut.blank?

      normalized = Customer.new(rut: rut).tap(&:normalize_rut).rut
      existing = @company.customers.find_by(rut: normalized)
      return existing if existing

      @company.customers.create!(
        rut:   normalized,
        name:  @params[:customer_name].presence || "Cliente #{normalized}",
        email: @params[:customer_email],
        giro:  @params[:customer_giro],
        address: @params[:customer_address],
        comuna: @params[:customer_comuna]
      )
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value) == true
    end
  end
end
