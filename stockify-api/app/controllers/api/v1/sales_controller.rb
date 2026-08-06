module Api
  module V1
    class SalesController < BaseController
      before_action :set_sale, only: %i[show issue]

      def index
        sales = company_sales.includes(:store, :user, sale_items: :product)
          .order(sold_on: :desc, created_at: :desc)

        sales = sales.where(store_id: params[:store_id]) if params[:store_id].present?

        render json: { sales: sales.limit(50).map { |sale| serialize_sale(sale) } }
      end

      def show
        render json: { sale: serialize_sale(@sale) }
      end

      def create
        sale = Sales::Creator.new(
          user: current_user,
          company: current_company,
          params: sale_params.to_h
        ).call
        render json: { sale: serialize_sale(sale.reload) }, status: :created
      end

      # Emite el DTE: asigna folio del CAF vigente y congela el documento.
      def issue
        @sale.issue!
        render json: { sale: serialize_sale(@sale.reload) }
      end

      private

      def company_sales
        Sale.joins(:store).where(stores: { company_id: current_company.id })
      end

      def set_sale
        @sale = company_sales.includes(:store, :user, sale_items: :product).find(params[:id])
      end

      def sale_params
        params.require(:sale).permit(
          :store_id, :status, :reference, :sold_on, :notes,
          :document_type, :issue,
          :customer_id, :customer_name, :customer_rut, :customer_email, :customer_giro,
          items: %i[product_id quantity unit_price]
        )
      end
    end
  end
end
