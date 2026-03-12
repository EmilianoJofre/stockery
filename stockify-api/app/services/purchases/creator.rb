module Purchases
  class Creator
    def initialize(user:, params:)
      @user = user
      @params = params.deep_symbolize_keys
    end

    def call
      Purchase.transaction do
        purchase = Purchase.new(
          supplier_id: @params[:supplier_id],
          store_id: @params[:store_id],
          status: normalized_status,
          reference: @params[:reference],
          received_on: @params[:received_on].presence || Date.current,
          notes: @params[:notes],
          user: @user
        )

        build_items(purchase)
        purchase.save!
        receive_inventory!(purchase) if purchase.received?
        purchase
      end
    end

    private

    def build_items(purchase)
      items = Array(@params[:items])
      raise InventoryManager::Error, "Debes agregar al menos una linea de compra" if items.empty?

      items.each do |item|
        purchase.purchase_items.build(
          product_id: item[:product_id],
          quantity: item[:quantity],
          unit_cost: item[:unit_cost]
        )
      end
    end

    def receive_inventory!(purchase)
      purchase.purchase_items.each do |item|
        InventoryManager.adjust!(
          product: item.product,
          store: purchase.store,
          user: @user,
          quantity_change: item.quantity,
          reason: "purchase",
          note: "Recibido por #{purchase.reference}"
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
