require "csv"

module Api
  module V1
    class ReportsController < BaseController
      before_action do
        authorize_roles!(:admin, :manager)
      end

      def stock_levels
        rows = InventoryLevel.includes(:product, :store).order("store_id ASC, product_id ASC").map do |level|
          {
            store: level.store.name,
            sku: level.product.sku,
            product: level.product.name,
            quantity: level.quantity,
            threshold: level.product.low_stock_threshold,
            low_stock: level.low_stock?
          }
        end

        respond_with_report("stock-levels", rows)
      end

      def top_selling_products
        rows = SaleItem.joins(:product, :sale)
          .merge(Sale.completed)
          .group("products.id", "products.name", "products.sku")
          .select("products.name AS product_name, products.sku AS sku, SUM(sale_items.quantity) AS quantity_sold, SUM(sale_items.subtotal) AS revenue")
          .order("SUM(sale_items.quantity) DESC")
          .map do |row|
            {
              sku: row.sku,
              product: row.product_name,
              quantity_sold: row.quantity_sold.to_i,
              revenue: row.revenue.to_f.round(2)
            }
          end

        respond_with_report("top-selling-products", rows)
      end

      def low_stock
        rows = InventoryLevel.includes(:product, :store)
          .select(&:low_stock?)
          .map do |level|
            {
              store: level.store.name,
              sku: level.product.sku,
              product: level.product.name,
              quantity: level.quantity,
              threshold: level.product.low_stock_threshold
            }
          end

        respond_with_report("low-stock-products", rows)
      end

      private

      def respond_with_report(filename, rows)
        if request.format.csv?
          csv = CSV.generate(headers: true) do |sheet|
            sheet << rows.first&.keys || []
            rows.each { |row| sheet << row.values }
          end

          send_data csv, filename: "#{filename}.csv", disposition: "attachment"
        else
          render json: { rows: rows }
        end
      end
    end
  end
end
