module Api
  module V1
    class ProductsController < BaseController
      before_action :set_product, only: [:show, :update, :destroy]
      before_action only: [:create, :update, :destroy] do
        authorize!("products.create")
      end

      def index
        records = filtered_products.to_a
        records = records.select(&:low_stock?) if params[:low_stock] == "true"
        render json: { products: records.map { |product| serialize_product(product) } }
      end

      def export
        authorize!("products.view")
        records = filtered_products
        records = records.select(&:low_stock?) if params[:low_stock] == "true"
        csv = Products::Exporter.new(scope: records).to_csv
        filename = "productos_#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
        send_data "\uFEFF#{csv}", filename: filename, type: "text/csv; charset=utf-8", disposition: "attachment"
      end

      def show
        render json: { product: serialize_product(@product) }
      end

      def create
        product = current_company.products.build(product_params)
        product.save!
        ensure_inventory_rows(product)

        render json: { product: serialize_product(product.reload) }, status: :created
      end

      def update
        authorize!("products.edit")
        @product.update!(product_params)
        render json: { product: serialize_product(@product.reload) }
      end

      def destroy
        authorize!("products.delete")
        @product.destroy!
        head :no_content
      end

      private

      def filtered_products
        products = current_company.products
          .includes(:product_category, inventory_levels: :store)
          .order(created_at: :desc)
        products = products.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)
        products = products.where(product_category_id: params[:category_ids]) if params[:category_ids].present?
        if params[:q].present?
          query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
          products = products.where("products.name ILIKE :query OR products.sku ILIKE :query", query: query)
        end
        products
      end

      def ensure_inventory_rows(product)
        current_company.stores.find_each do |store|
          InventoryLevel.find_or_create_by!(product: product, store: store) do |level|
            level.quantity = 0
          end
        end
      end

      def set_product
        @product = current_company.products.includes(:product_category, inventory_levels: :store).find(params[:id])
      end

      def product_params
        params.require(:product).permit(:name, :sku, :description, :price, :low_stock_threshold, :active, :product_category_id)
      end
    end
  end
end
