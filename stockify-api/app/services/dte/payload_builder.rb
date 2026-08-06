module Dte
  # Traduce una Sale al encabezado/detalle que exige el SII.
  #
  # Se usa la nomenclatura del SII (Encabezado, IdDoc, Emisor, Receptor,
  # Totales, Detalle) y no una propia porque es la misma estructura del XML
  # oficial: los proveedores la reflejan en JSON, y si algun dia se certifica
  # software propio este payload se serializa a XML sin rehacerlo.
  #
  # OJO: el esquema de la BOLETA difiere del de la FACTURA, y el ORDEN de los
  # elementos importa (es validacion XSD, no JSON libre). Ambas cosas fueron
  # verificadas contra la API de OpenFactura, que rechaza el documento con
  # "Validacion de Esquema" si se envia un campo de mas o fuera de lugar.
  class PayloadBuilder
    # RUT generico del SII para consumidor final anonimo. Una boleta sin cliente
    # identificado igual debe declarar receptor.
    ANONYMOUS_RUT = "66666666-6".freeze

    BOLETA_TYPES = [39, 41].freeze

    def initialize(sale)
      @sale = sale
      @setting = sale.store.company.dte_setting
      @type_code = Sale.document_types[sale.document_type]
    end

    def call
      {
        "Encabezado" => {
          "IdDoc"    => id_doc,
          "Emisor"   => emisor,
          "Receptor" => receptor,
          "Totales"  => totales
        },
        "Detalle"    => detalle,
        "Referencia" => referencia
      }.compact
    end

    private

    attr_reader :sale, :setting, :type_code

    def boleta?
      BOLETA_TYPES.include?(type_code)
    end

    def id_doc
      doc = { "TipoDTE" => type_code }
      # Con folio propio se envia el que ya reservamos; si lo asigna el
      # proveedor, se omite y llega en la respuesta.
      doc["Folio"] = sale.folio if sale.folio.present?
      doc["FchEmis"] = sale.sold_on.to_s
      # Obligatorio en boleta: 3 = boleta de venta y servicios.
      doc["IndServicio"] = 3 if boleta?
      doc
    end

    # El SII nombra distinto los MISMOS datos segun el tipo de documento: la
    # boleta usa RznSocEmisor/GiroEmisor, la factura usa RznSoc/GiroEmis. Y
    # `Acteco` solo existe en factura. Verificado contra la API: enviar los
    # nombres de boleta en una factura devuelve "Se espera uno del tipo: RznSoc".
    def emisor
      base = { "RUTEmisor" => setting&.rut_emisor }

      if boleta?
        base["RznSocEmisor"] = setting&.razon_social
        base["GiroEmisor"]   = setting&.giro
      else
        base["RznSoc"]  = setting&.razon_social
        base["GiroEmis"] = setting&.giro
        base["Acteco"]  = setting&.acteco
      end

      base.merge(
        "CdgSIISucur" => setting&.cdg_sii_sucur,
        "DirOrigen"   => setting&.dir_origen,
        "CmnaOrigen"  => setting&.cmna_origen
      ).compact
    end

    def receptor
      customer = sale.customer

      if customer.blank?
        return {
          "RUTRecep"    => ANONYMOUS_RUT,
          "RznSocRecep" => sale.customer_name.presence || "Consumidor final"
        }
      end

      {
        "RUTRecep"    => customer.rut.presence || ANONYMOUS_RUT,
        "RznSocRecep" => customer.name,
        "GiroRecep"   => customer.giro,
        "DirRecep"    => customer.address,
        # Obligatorio en factura.
        "CmnaRecep"   => customer.comuna,
        "CorreoRecep" => customer.email
      }.compact
    end

    def totales
      if boleta?
        # En boleta los montos son BRUTOS, igual que nuestros precios: se envian
        # tal cual y el desglose ya cuadra.
        base = { "MntNeto" => sale.net_amount.to_i }
        base["MntExe"] = sale.exempt_amount.to_i if sale.exempt_amount.to_i.positive?
        return base.merge(
          "IVA"      => sale.tax_amount.to_i,
          "MntTotal" => sale.total_amount.to_i
        )
      end

      # En factura los montos son NETOS y el SII recalcula el IVA sobre ellos,
      # asi que el total se reconstruye desde las lineas netas en vez de reusar
      # el desglose derivado del bruto.
      neto = taxable_lines.sum { |line| line["MontoItem"] }
      exento = exempt_lines.sum { |line| line["MontoItem"] }
      iva = (neto * sale.tax_rate.to_f).round

      base = { "MntNeto" => neto }
      base["MntExe"] = exento if exento.positive?
      base.merge(
        "TasaIVA"  => (sale.tax_rate.to_f * 100).round,
        "IVA"      => iva,
        "MntTotal" => neto + iva + exento
      )
    end

    def taxable_lines
      detalle.reject { |line| line["IndExe"] == 1 }
    end

    def exempt_lines
      detalle.select { |line| line["IndExe"] == 1 }
    end

    # Bloque obligatorio en una nota de credito: identifica el documento que
    # corrige. Sin el, el SII la rechaza.
    def referencia
      origen = sale.references_sale
      return nil if origen.blank?

      [{
        "NroLinRef" => 1,
        "TpoDocRef" => Sale.document_types[origen.document_type],
        "FolioRef"  => origen.folio,
        "FchRef"    => origen.sold_on.to_s,
        "CodRef"    => sale.reference_code,
        "RazonRef"  => sale.reference_reason
      }.compact]
    end

    # Se memoiza porque `totales` lo consulta para reconstruir los montos de la
    # factura: recalcularlo daria las mismas lineas pero es trabajo repetido.
    def detalle
      @detalle ||= sale.sale_items.each_with_index.map do |item, index|
        unit = line_unit_price(item)

        line = {
          "NroLinDet" => index + 1,
          "NmbItem"   => item.product.name,
          "QtyItem"   => item.quantity,
          "PrcItem"   => unit,
          "MontoItem" => unit * item.quantity
        }
        # IndExe = 1 marca la linea como exenta de IVA.
        line["IndExe"] = 1 if item.tax_exempt
        line
      end
    end

    # Nuestros precios son BRUTOS (precio de gondola). La boleta los espera asi,
    # pero la factura espera el NETO por unidad y calcula el IVA encima.
    #
    # OJO: convertir bruto -> neto redondea, asi que el total de una factura
    # puede diferir en 1-2 pesos del total mostrado en la app. La solucion
    # limpia es capturar precios netos al emitir facturas, que es una decision
    # de producto pendiente.
    def line_unit_price(item)
      gross = item.unit_price.to_i
      return gross if boleta? || item.tax_exempt

      (gross / (1 + sale.tax_rate.to_f)).round
    end
  end
end
