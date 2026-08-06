module Api
  module V1
    class DashboardController < BaseController
      def show
        company_product_ids = current_company.products.pluck(:id)
        company_store_ids = current_company.stores.pluck(:id)

        low_stock = InventoryLevel.includes(:product, :store)
          .where(product_id: company_product_ids)
          .order(updated_at: :desc)
          .select(&:low_stock?)
          .first(6)

        recent_purchases = Purchase.includes(:supplier, :store, :user, purchase_items: :product)
          .where(store_id: company_store_ids)
          .order(received_on: :desc, created_at: :desc)
          .limit(5)

        recent_sales = Sale.includes(:store, :user, sale_items: :product)
          .where(store_id: company_store_ids)
          .order(sold_on: :desc, created_at: :desc)
          .limit(5)

        render json: {
          metrics: {
            total_products: current_company.products.count,
            active_stores: current_company.stores.active.count,
            low_stock_alerts: low_stock.size,
            # Ingreso NETO: excluye ventas anuladas y descuenta las notas de
            # credito. Sumar `total_amount` a secas contaria las notas de
            # credito como ingreso y seguiria contando lo anulado.
            sales_month: Sale.net_revenue(
              Sale.where(store_id: company_store_ids)
                .where(sold_on: Date.current.beginning_of_month..Date.current)
            ),
            purchases_month: Purchase.where(store_id: company_store_ids)
              .received
              .where(received_on: Date.current.beginning_of_month..Date.current)
              .sum(:total_amount).to_f.round(2)
          },
          low_stock_alerts: low_stock.map { |level| serialize_inventory_level(level) },
          recent_purchases: recent_purchases.map { |purchase| serialize_purchase(purchase) },
          recent_sales: recent_sales.map { |sale| serialize_sale(sale) }
        }
      end
    end
  end
end
