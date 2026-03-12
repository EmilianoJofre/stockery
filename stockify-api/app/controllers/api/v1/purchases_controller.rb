module Api
  module V1
    class PurchasesController < BaseController
      before_action :set_purchase, only: [:show]
      before_action only: [:create] do
        authorize_roles!(:admin, :manager)
      end

      def index
        purchases = Purchase.includes(:supplier, :store, :user, purchase_items: :product)
          .order(received_on: :desc, created_at: :desc)

        purchases = purchases.where(store_id: params[:store_id]) if params[:store_id].present?

        render json: { purchases: purchases.limit(50).map { |purchase| serialize_purchase(purchase) } }
      end

      def show
        render json: { purchase: serialize_purchase(@purchase) }
      end

      def create
        purchase = Purchases::Creator.new(user: current_user, params: purchase_params.to_h).call
        render json: { purchase: serialize_purchase(purchase.reload) }, status: :created
      end

      private

      def set_purchase
        @purchase = Purchase.includes(:supplier, :store, :user, purchase_items: :product).find(params[:id])
      end

      def purchase_params
        params.require(:purchase).permit(:supplier_id, :store_id, :status, :reference, :received_on, :notes, items: [:product_id, :quantity, :unit_cost])
      end
    end
  end
end
