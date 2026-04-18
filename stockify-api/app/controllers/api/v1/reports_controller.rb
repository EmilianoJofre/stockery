require "csv"

module Api
  module V1
    class ReportsController < BaseController
      before_action do
        authorize!("reports.view")
      end

      def stock_levels
        company_product_ids = current_company.products.pluck(:id)

        rows = InventoryLevel.includes(:product, :store)
          .where(product_id: company_product_ids)
          .order("store_id ASC, product_id ASC")
          .map do |level|
            {
              tienda: level.store.name,
              sku: level.product.sku,
              producto: level.product.name,
              cantidad: level.quantity,
              umbral: level.product.low_stock_threshold,
              stock_bajo: level.low_stock?
            }
          end

        respond_with_report("stock-levels", rows)
      end

      def top_selling_products
        company_store_ids = current_company.stores.pluck(:id)

        rows = SaleItem.joins(:product, :sale)
          .merge(Sale.completed.where(store_id: company_store_ids))
          .group("products.id", "products.name", "products.sku")
          .select("products.name AS product_name, products.sku AS sku, SUM(sale_items.quantity) AS quantity_sold, SUM(sale_items.subtotal) AS revenue")
          .order("SUM(sale_items.quantity) DESC")
          .map do |row|
            {
              sku: row.sku,
              producto: row.product_name,
              cantidad_vendida: row.quantity_sold.to_i,
              ingresos: row.revenue.to_f.round(2)
            }
          end

        respond_with_report("top-selling-products", rows)
      end

      def low_stock
        company_product_ids = current_company.products.pluck(:id)

        rows = InventoryLevel.includes(:product, :store)
          .where(product_id: company_product_ids)
          .select(&:low_stock?)
          .map do |level|
            {
              tienda: level.store.name,
              sku: level.product.sku,
              producto: level.product.name,
              cantidad: level.quantity,
              umbral: level.product.low_stock_threshold
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
