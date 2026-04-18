module Api
  module V1
    class StoresController < BaseController
      def index
        stores = current_company.stores.order(:name)
        render json: { stores: stores.map { |store| serialize_store(store) } }
      end
    end
  end
end
