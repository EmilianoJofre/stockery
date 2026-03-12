module Api
  module V1
    class InventoryController < BaseController
      before_action only: [:adjust] do
        authorize_roles!(:admin, :manager)
      end

      def index
        levels = InventoryLevel.includes(:product, :store).joins(:product, :store).order("stores.name ASC, products.name ASC")

        if params[:q].present?
          query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
          levels = levels.where("products.name ILIKE :query OR products.sku ILIKE :query", query: query)
        end

        levels = levels.where(store_id: params[:store_id]) if params[:store_id].present?

        rows = levels.to_a
        rows = rows.select(&:low_stock?) if params[:low_stock] == "true"

        render json: {
          inventory: rows.map { |level| serialize_inventory_level(level) },
          adjustments: recent_adjustment_payload
        }
      end

      def adjustments
        render json: { adjustments: recent_adjustment_payload(limit: 25) }
      end

      def adjust
        level = InventoryManager.adjust!(
          product: Product.find(adjust_params[:product_id]),
          store: Store.find(adjust_params[:store_id]),
          user: current_user,
          quantity_change: adjust_params[:quantity_change],
          reason: adjust_params[:reason],
          note: adjust_params[:note]
        )

        render json: { inventory_level: serialize_inventory_level(level.reload) }, status: :created
      end

      private

      def recent_adjustment_payload(limit: 10)
        InventoryAdjustment.includes(:product, :store, :user)
          .order(created_at: :desc)
          .limit(limit)
          .map { |adjustment| serialize_adjustment(adjustment) }
      end

      def adjust_params
        params.require(:adjustment).permit(:product_id, :store_id, :quantity_change, :reason, :note)
      end
    end
  end
end
