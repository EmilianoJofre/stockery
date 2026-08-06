module Dte
  # Error de dominio de la emision electronica.
  #
  # Distingue fallas reintentables (red, 5xx del proveedor) de definitivas
  # (payload rechazado): solo las primeras tiene sentido reintentar, y esa
  # distincion es la que usa DteTransmissionJob para decidir.
  class TransmissionError < StandardError
    attr_reader :retryable, :details

    def initialize(message, retryable: false, details: nil)
      super(message)
      @retryable = retryable
      @details = details
    end

    def retryable?
      retryable
    end
  end
end
