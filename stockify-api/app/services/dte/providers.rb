module Dte
  # Fabrica de proveedores de emision. Cada proveedor expone un unico metodo:
  #
  #   transmit(sale, payload) -> Dte::Receipt
  #
  # Mantener la interfaz minima es lo que permite cambiar de proveedor (o pasar
  # a software propio certificado) reemplazando una clase, sin tocar el modelo.
  module Providers
    def self.build(setting)
      case setting.provider
      when "simulated"   then Simulated.new(setting)
      when "openfactura" then OpenFactura.new(setting)
      else
        raise TransmissionError, "Proveedor DTE desconocido: #{setting.provider}"
      end
    end
  end
end
