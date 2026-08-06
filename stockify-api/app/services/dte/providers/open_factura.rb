require "net/http"
require "uri"
require "json"

module Dte
  module Providers
    # Adaptador para OpenFactura (Haulmer).
    #
    # VERIFICADO contra el ambiente de demostracion (dev-api.haulmer.com) con
    # la apikey publica del plugin oficial de WooCommerce: boleta (39), factura
    # (33) y nota de credito (61) emitidas con folio y track id reales.
    #
    # OpenFactura administra los folios: por eso `folio_strategy` debe ser
    # "provider" con este adaptador, y el folio llega en la respuesta.
    #
    # El ambiente de demostracion solo acepta documentos de la organizacion de
    # prueba de Haulmer: los datos del emisor deben ser los suyos, no los de la
    # empresa real. Se obtienen con GET /v2/dte/organization.
    class OpenFactura
      BASE_URLS = {
        "sandbox"    => "https://dev-api.haulmer.com",
        "production" => "https://api.haulmer.com"
      }.freeze

      DOCUMENT_PATH = "/v2/dte/document".freeze
      TIMEOUT_SECONDS = 20

      def initialize(setting)
        @setting = setting
      end

      def transmit(sale, payload)
        response = post(DOCUMENT_PATH, { "dte" => payload, "response" => %w[FOLIO PDF] })

        Dte::Receipt.new(
          status: "sent",
          folio: response["FOLIO"] || sale.folio,
          track_id: response["TOKEN"] || response["trackid"] || response["TrackId"],
          raw: response
        )
      end

      private

      attr_reader :setting

      def base_url
        BASE_URLS.fetch(setting.environment) do
          raise Dte::TransmissionError.new("Ambiente desconocido: #{setting.environment}")
        end
      end

      def post(path, body)
        uri = URI.join(base_url, path)

        request = Net::HTTP::Post.new(uri)
        request["apikey"] = setting.api_key
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)

        response = perform(uri, request)
        parse!(response)
      end

      def perform(uri, request)
        Net::HTTP.start(
          uri.host, uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: TIMEOUT_SECONDS,
          read_timeout: TIMEOUT_SECONDS
        ) { |http| http.request(request) }
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
        # Fallas de red: el documento pudo haberse emitido o no. Se reintenta,
        # y la idempotencia la da el folio ya reservado.
        raise Dte::TransmissionError.new("No se pudo contactar a OpenFactura: #{e.message}", retryable: true)
      end

      def parse!(response)
        body = begin
          response.body.present? ? JSON.parse(response.body) : {}
        rescue JSON::ParserError
          { "raw_body" => response.body }
        end

        return body if response.is_a?(Net::HTTPSuccess)

        code = response.code.to_i
        message = body.dig("error", "message") || body["message"] || "HTTP #{code}"

        raise Dte::TransmissionError.new(
          "OpenFactura rechazo el documento: #{message}",
          # 5xx y 429 son transitorios; 4xx significa que el payload esta mal
          # y reintentarlo daria el mismo resultado.
          retryable: code >= 500 || code == 429,
          details: body
        )
      end
    end
  end
end
