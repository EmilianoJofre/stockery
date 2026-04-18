module Api
  module V1
    class InventoryController < BaseController
      before_action only: [:adjust] do
        authorize!("inventory.adjust")
      end

      def index
        levels = company_inventory_levels.includes(:product, :store)
          .joins(:product, :store)
          .order("stores.name ASC, products.name ASC")

        if params[:q].present?
          query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
          levels = levels.where("products.name ILIKE :query OR products.sku ILIKE :query", query: query)
        end

        levels = levels.where(store_id: params[:store_id]) if params[:store_id].present?
        levels = levels.where(products: { product_category_id: params[:category_ids] }) if params[:category_ids].present?

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
        product = current_company.products.find(adjust_params[:product_id])
        store_id = adjust_params[:store_id].presence || current_company.default_store&.id
        raise InventoryManager::Error, "La compañía no tiene ninguna tienda activa" unless store_id
        store = current_company.stores.find(store_id)

        level = InventoryManager.adjust!(
          product: product,
          store: store,
          user: current_user,
          quantity_change: adjust_params[:quantity_change],
          reason: adjust_params[:reason],
          note: adjust_params[:note]
        )

        render json: { inventory_level: serialize_inventory_level(level.reload) }, status: :created
      end

      private

      def company_inventory_levels
        InventoryLevel.joins(:product).where(products: { company_id: current_company.id })
      end

      def recent_adjustment_payload(limit: 10)
        InventoryAdjustment.includes(:product, :store, :user)
          .joins(:product)
          .where(products: { company_id: current_company.id })
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
