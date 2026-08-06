module Dte
  # Orquesta la emision de un DTE.
  #
  # La emision se parte en dos fases a proposito:
  #
  #   1. `issue!` — local y rapida: reserva folio (si el folio es propio), marca
  #      el documento como emitido e inmutable, y lo deja en cola.
  #   2. `transmit!` — remota: habla con el proveedor y actualiza el estado.
  #
  # Estan separadas porque una caida del proveedor no puede bloquear la venta
  # en el mostrador. El documento queda `queued` y se retransmite despues.
  class Emitter
    def initialize(sale)
      @sale = sale
      @company = sale.store.company
    end

    def issue!
      raise Sale::Immutable, "El documento #{sale.reference} ya fue emitido" if sale.issued?

      setting = resolve_setting!

      Sale.transaction do
        folio, caf_range = reserve_folio(setting)

        sale.update_columns(
          folio: folio,
          caf_range_id: caf_range&.id,
          issued_at: Time.current,
          sii_status: Sale.sii_statuses[:queued],
          updated_at: Time.current
        )
      end

      DteTransmissionJob.perform_later(sale.id)
      sale
    end

    # Idempotente: un documento ya aceptado no se reenvia.
    def transmit!
      return sale if sale.sii_accepted?
      raise TransmissionError.new("El documento #{sale.reference} no ha sido emitido") unless sale.issued?

      setting = resolve_setting!
      payload = PayloadBuilder.new(sale).call

      receipt = setting.to_provider.transmit(sale, payload)

      sale.update_columns(
        folio: sale.folio || receipt.folio,
        sii_status: Sale.sii_statuses.fetch(receipt.status, Sale.sii_statuses[:sent]),
        sii_track_id: receipt.track_id,
        updated_at: Time.current
      )

      sale
    rescue TransmissionError => e
      # Solo se marca rechazado cuando la falla es definitiva: si es de red, el
      # documento sigue en cola para reintentar.
      unless e.retryable?
        sale.update_columns(sii_status: Sale.sii_statuses[:rejected], updated_at: Time.current)
      end
      raise
    end

    private

    attr_reader :sale, :company

    def resolve_setting!
      setting = company.dte_setting
      return setting if setting&.active?

      raise TransmissionError.new(
        "La empresa #{company.name} no tiene configurada la emision electronica"
      )
    end

    # Con folio del proveedor no se reserva nada: llega en la respuesta.
    def reserve_folio(setting)
      return [nil, nil] if setting.provider_assigns_folio?

      CafRange.assign_folio!(
        company: company,
        document_type: Sale.document_types[sale.document_type]
      )
    end
  end
end
