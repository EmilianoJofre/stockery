module Api
  module V1
    class BillingController < BaseController
      before_action { authorize!("billing.manage") }

      def show
        render json: {
          settings: current_setting ? serialize_dte_setting(current_setting) : nil,
          caf_ranges: current_company.caf_ranges.order(:document_type, :range_start)
            .map { |range| serialize_caf_range(range) },
          providers: DteSetting::PROVIDERS,
          environments: DteSetting::ENVIRONMENTS,
          folio_strategies: DteSetting::FOLIO_STRATEGIES,
          document_types: Sale.document_types
        }
      end

      def update
        setting = current_setting || current_company.build_dte_setting
        setting.assign_attributes(setting_params)
        setting.save!

        render json: { settings: serialize_dte_setting(setting) }
      end

      def create_caf_range
        range = current_company.caf_ranges.new(caf_range_params)
        # El folio siguiente arranca en el inicio del rango salvo que se indique
        # otro (util al migrar desde otro sistema con folios ya consumidos).
        range.next_folio = range.range_start if range.next_folio.blank?
        range.save!

        render json: { caf_range: serialize_caf_range(range) }, status: :created
      end

      def update_caf_range
        range = current_company.caf_ranges.find(params[:id])
        # Solo se permite activar/desactivar: cambiar los limites de un rango ya
        # en uso desalinearia los folios entregados.
        range.update!(active: ActiveModel::Type::Boolean.new.cast(params[:active]))

        render json: { caf_range: serialize_caf_range(range) }
      end

      private

      def current_setting
        @current_setting ||= current_company.dte_setting
      end

      def setting_params
        permitted = params.require(:settings).permit(
          :provider, :environment, :folio_strategy, :api_key, :active,
          :rut_emisor, :razon_social, :giro, :acteco,
          :dir_origen, :cmna_origen, :cdg_sii_sucur
        )

        # Una api_key vacia significa "no la cambies", no "borrala": el
        # formulario nunca recibe la credencial actual de vuelta.
        permitted.delete(:api_key) if permitted[:api_key].blank?
        permitted
      end

      def caf_range_params
        params.require(:caf_range).permit(
          :document_type, :range_start, :range_end, :next_folio,
          :authorized_on, :expires_on, :active
        )
      end
    end
  end
end
