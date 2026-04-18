module Api
  module V1
    class ProductCategoriesController < BaseController
      def index
        categories = current_company.product_categories.active.order(:name)
        render json: { product_categories: categories.map { |c| serialize_product_category(c) } }
      end

      def create
        authorize!("products.create")
        category = current_company.product_categories.create!(category_params)
        render json: { product_category: serialize_product_category(category) }, status: :created
      end

      def update
        authorize!("products.edit")
        category = current_company.product_categories.find(params[:id])
        category.update!(category_params)
        render json: { product_category: serialize_product_category(category) }
      end

      private

      def category_params
        params.require(:product_category).permit(:name, :active)
      end
    end
  end
end
