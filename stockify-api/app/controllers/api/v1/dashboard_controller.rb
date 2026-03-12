module Api
  module V1
    class DashboardController < BaseController
      def show
        low_stock = InventoryLevel.includes(:product, :store)
          .order(updated_at: :desc)
          .select(&:low_stock?)
          .first(6)

        recent_purchases = Purchase.includes(:supplier, :store, :user, purchase_items: :product)
          .order(received_on: :desc, created_at: :desc)
          .limit(5)

        recent_sales = Sale.includes(:store, :user, sale_items: :product)
          .order(sold_on: :desc, created_at: :desc)
          .limit(5)

        render json: {
          metrics: {
            total_products: Product.count,
            active_stores: Store.active.count,
            low_stock_alerts: low_stock.size,
            sales_month: Sale.completed.where(sold_on: Date.current.beginning_of_month..Date.current).sum(:total_amount).to_f.round(2),
            purchases_month: Purchase.received.where(received_on: Date.current.beginning_of_month..Date.current).sum(:total_amount).to_f.round(2)
          },
          low_stock_alerts: low_stock.map { |level| serialize_inventory_level(level) },
          recent_purchases: recent_purchases.map { |purchase| serialize_purchase(purchase) },
          recent_sales: recent_sales.map { |sale| serialize_sale(sale) }
        }
      end
    end
  end
end
