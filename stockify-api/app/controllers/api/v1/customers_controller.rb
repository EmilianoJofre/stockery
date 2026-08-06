module Api
  module V1
    class CustomersController < BaseController
      before_action :set_customer, only: %i[show update]

      def index
        customers = current_company.customers.order(:name)

        if params[:q].present?
          query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
          customers = customers.where("name ILIKE :query OR rut ILIKE :query", query: query)
        end

        customers = customers.active if params[:active] == "true"

        render json: { customers: customers.limit(100).map { |c| serialize_customer(c) } }
      end

      def show
        render json: { customer: serialize_customer(@customer) }
      end

      def create
        customer = current_company.customers.create!(customer_params)
        render json: { customer: serialize_customer(customer) }, status: :created
      end

      def update
        @customer.update!(customer_params)
        render json: { customer: serialize_customer(@customer) }
      end

      private

      def set_customer
        @customer = current_company.customers.find(params[:id])
      end

      def customer_params
        params.require(:customer).permit(:rut, :name, :giro, :email, :phone, :address, :active)
      end
    end
  end
end
