module Api
  module V1
    class SalesController < BaseController
      before_action :set_sale, only: [:show]

      def index
        sales = Sale.includes(:store, :user, sale_items: :product)
          .order(sold_on: :desc, created_at: :desc)

        sales = sales.where(store_id: params[:store_id]) if params[:store_id].present?

        render json: { sales: sales.limit(50).map { |sale| serialize_sale(sale) } }
      end

      def show
        render json: { sale: serialize_sale(@sale) }
      end

      def create
        sale = Sales::Creator.new(user: current_user, params: sale_params.to_h).call
        render json: { sale: serialize_sale(sale.reload) }, status: :created
      end

      private

      def set_sale
        @sale = Sale.includes(:store, :user, sale_items: :product).find(params[:id])
      end

      def sale_params
        params.require(:sale).permit(:store_id, :status, :reference, :sold_on, :customer_name, :notes, items: [:product_id, :quantity, :unit_price])
      end
    end
  end
end
