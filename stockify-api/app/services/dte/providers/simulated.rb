module Dte
  module Providers
    # Proveedor de desarrollo: no sale a internet y acepta todo documento bien
    # formado. Existe para que el flujo completo (folio, emision, inmutabilidad,
    # estado ante el SII) sea ejecutable y testeable sin certificado ni cuenta.
    #
    # NO es un emisor valido: no firma nada y el SII no conoce estos documentos.
    class Simulated
      def initialize(setting)
        @setting = setting
      end

      def transmit(sale, payload)
        validate!(payload)

        Dte::Receipt.new(
          status: "accepted",
          # Si la estrategia es "provider", aca se simula el folio que
          # normalmente devolveria el servicio remoto.
          folio: sale.folio || simulated_folio(sale),
          track_id: "SIM-#{sale.id}-#{sale.reference}",
          raw: { "simulated" => true, "payload" => payload }
        )
      end

      private

      attr_reader :setting

      # Las mismas validaciones que rechazaria el SII, para que el simulado no
      # deje pasar documentos que en produccion fallarian.
      def validate!(payload)
        totales = payload.dig("Encabezado", "Totales") || {}
        suma = totales["MntNeto"].to_i + totales["IVA"].to_i + totales["MntExe"].to_i

        if suma != totales["MntTotal"].to_i
          raise Dte::TransmissionError.new(
            "El desglose no cuadra: neto + IVA + exento = #{suma}, total = #{totales['MntTotal']}",
            retryable: false
          )
        end

        if Array(payload["Detalle"]).empty?
          raise Dte::TransmissionError.new("El documento no tiene lineas de detalle", retryable: false)
        end

        tipo = payload.dig("Encabezado", "IdDoc", "TipoDTE")
        if [33, 34].include?(tipo) && payload.dig("Encabezado", "Receptor").blank?
          raise Dte::TransmissionError.new("Una factura exige receptor identificado", retryable: false)
        end
      end

      def simulated_folio(sale)
        sale.id
      end
    end
  end
end
