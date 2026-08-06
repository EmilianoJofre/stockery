class DteTransmissionJob < ApplicationJob
  queue_as :default

  retry_on Dte::TransmissionError, wait: :polynomially_longer, attempts: 5

  def perform(sale_id)
    sale = Sale.find_by(id: sale_id)
    return if sale.nil?

    Dte::Emitter.new(sale).transmit!
  rescue Dte::TransmissionError => e
    # Solo se relanza lo transitorio, para que `retry_on` lo reintente. Un
    # rechazo por payload invalido se descarta aca: reintentarlo daria el mismo
    # resultado y el documento ya quedo marcado como `rejected`.
    raise if e.retryable?

    Rails.logger.error("[DTE] Rechazo definitivo en la venta #{sale_id}: #{e.message}")
    nil
  end
end
