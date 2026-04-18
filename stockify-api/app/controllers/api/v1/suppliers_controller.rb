module Api
  module V1
    class SuppliersController < BaseController
      before_action :set_supplier, only: [:show, :update, :destroy]
      before_action only: [:create, :update] do
        authorize!("suppliers.create")
      end
      before_action only: [:destroy] do
        authorize!("suppliers.delete")
      end

      def index
        suppliers = current_company.suppliers.order(:name)
        render json: { suppliers: suppliers.map { |supplier| serialize_supplier(supplier) } }
      end

      def show
        render json: { supplier: serialize_supplier(@supplier) }
      end

      def create
        supplier = current_company.suppliers.create!(supplier_params)
        render json: { supplier: serialize_supplier(supplier) }, status: :created
      end

      def update
        authorize!("suppliers.edit")
        @supplier.update!(supplier_params)
        render json: { supplier: serialize_supplier(@supplier) }
      end

      def destroy
        @supplier.destroy!
        head :no_content
      end

      private

      def set_supplier
        @supplier = current_company.suppliers.find(params[:id])
      end

      def supplier_params
        params.require(:supplier).permit(:name, :contact_name, :email, :phone, :notes, :active)
      end
    end
  end
end
