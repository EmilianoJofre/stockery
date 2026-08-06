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

      # Lotes con saldo. `expiring_within` (dias) es la base del insight
      # "que productos van a vencer".
      def lots
        lots = InventoryLot.available
          .includes(:product, :store)
          .joins(:product)
          .where(products: { company_id: current_company.id })

        lots = lots.where(store_id: params[:store_id]) if params[:store_id].present?
        lots = lots.where(product_id: params[:product_id]) if params[:product_id].present?

        if params[:expiring_within].present?
          horizon = Date.current + params[:expiring_within].to_i.days
          lots = lots.expiring_on_or_before(horizon)
        end

        lots = lots.expired if params[:expired] == "true"

        render json: { lots: lots.fefo.limit(200).map { |lot| serialize_inventory_lot(lot) } }
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
        InventoryMovement.includes(:product, :store, :user, :inventory_lot)
          .joins(:product)
          .where(products: { company_id: current_company.id })
          .recent_first
          .limit(limit)
          .map { |movement| serialize_adjustment(movement) }
      end

      def adjust_params
        params.require(:adjustment).permit(:product_id, :store_id, :quantity_change, :reason, :note)
      end
    end
  end
end
