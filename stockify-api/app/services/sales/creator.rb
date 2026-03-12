module Sales
  class Creator
    def initialize(user:, params:)
      @user = user
      @params = params.deep_symbolize_keys
    end

    def call
      Sale.transaction do
        sale = Sale.new(
          store_id: @params[:store_id],
          status: normalized_status,
          reference: @params[:reference],
          sold_on: @params[:sold_on].presence || Date.current,
          customer_name: @params[:customer_name],
          notes: @params[:notes],
          user: @user
        )

        build_items(sale)
        sale.save!
        commit_inventory!(sale) if sale.completed?
        sale
      end
    end

    private

    def build_items(sale)
      items = Array(@params[:items])
      raise InventoryManager::Error, "At least one sale item is required" if items.empty?

      items.each do |item|
        product = Product.find(item[:product_id])

        sale.sale_items.build(
          product: product,
          quantity: item[:quantity],
          unit_price: item[:unit_price].presence || product.price
        )
      end
    end

    def commit_inventory!(sale)
      sale.sale_items.each do |item|
        InventoryManager.adjust!(
          product: item.product,
          store: sale.store,
          user: @user,
          quantity_change: -item.quantity,
          reason: "sale",
          note: "Sold via #{sale.reference}"
        )
      end
    end

    def normalized_status
      status = @params[:status].to_s
      return status if Sale.statuses.key?(status)

      "completed"
    end
  end
end
