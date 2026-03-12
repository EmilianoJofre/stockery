module Api
  module V1
    class ProductsController < BaseController
      before_action :set_product, only: [:show, :update, :destroy]
      before_action only: [:create, :update, :destroy] do
        authorize_roles!(:admin, :manager)
      end

      def index
        products = Product.includes(inventory_levels: :store).order(created_at: :desc)
        products = products.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)

        if params[:q].present?
          query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
          products = products.where("products.name ILIKE :query OR products.sku ILIKE :query", query: query)
        end

        records = products.to_a
        records = records.select(&:low_stock?) if params[:low_stock] == "true"

        render json: { products: records.map { |product| serialize_product(product) } }
      end

      def show
        render json: { product: serialize_product(@product) }
      end

      def create
        product = Product.new(product_params)
        product.save!
        ensure_inventory_rows(product)

        render json: { product: serialize_product(product.reload) }, status: :created
      end

      def update
        @product.update!(product_params)
        render json: { product: serialize_product(@product.reload) }
      end

      def destroy
        @product.destroy!
        head :no_content
      end

      private

      def ensure_inventory_rows(product)
        Store.find_each do |store|
          InventoryLevel.find_or_create_by!(product: product, store: store) do |level|
            level.quantity = 0
          end
        end
      end

      def set_product
        @product = Product.includes(inventory_levels: :store).find(params[:id])
      end

      def product_params
        params.require(:product).permit(:name, :sku, :description, :price, :low_stock_threshold, :active)
      end
    end
  end
end
