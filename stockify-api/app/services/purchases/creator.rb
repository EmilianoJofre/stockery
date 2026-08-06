module Purchases
  class Creator
    def initialize(user:, params:, company: nil)
      @user = user
      @company = company || user.company
      @params = params.deep_symbolize_keys
    end

    def call
      Purchase.transaction do
        purchase = Purchase.new(
          supplier_id: @params[:supplier_id],
          store:        resolve_store!,
          status:       normalized_status,
          reference:    @params[:reference],
          received_on:  @params[:received_on].presence || Date.current,
          notes:        @params[:notes],
          user:         @user
        )

        build_items(purchase)
        purchase.save!
        receive_inventory!(purchase) if purchase.received?
        purchase
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

    def build_items(purchase)
      items = Array(@params[:items])
      raise InventoryManager::Error, "Debes agregar al menos una linea de compra" if items.empty?

      items.each do |item|
        purchase.purchase_items.build(
          product_id:  item[:product_id],
          quantity:    item[:quantity],
          unit_cost:   item[:unit_cost],
          lot_code:    item[:lot_code],
          expiry_date: item[:expiry_date]
        )
      end
    end

    def receive_inventory!(purchase)
      purchase.purchase_items.each do |item|
        InventoryManager.receive!(
          product:       item.product,
          store:         purchase.store,
          user:          @user,
          quantity:      item.quantity,
          unit_cost:     item.unit_cost,
          expiry_date:   item.expiry_date,
          lot_code:      item.lot_code,
          received_on:   purchase.received_on,
          reason:        "purchase",
          source:        purchase,
          purchase_item: item,
          note:          "Recibido por #{purchase.reference}"
        )
      end
    end

    def normalized_status
      status = @params[:status].to_s
      return status if Purchase.statuses.key?(status)
      "received"
    end
  end
end
