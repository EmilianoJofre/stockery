module Dte
  # Traduce una Sale al encabezado/detalle que exige el SII.
  #
  # Se usa la nomenclatura del SII (Encabezado, IdDoc, Emisor, Receptor,
  # Totales, Detalle) y no una propia porque es la misma estructura del XML
  # oficial: los proveedores la reflejan en JSON, y si algun dia se certifica
  # software propio este payload se serializa a XML sin rehacerlo.
  class PayloadBuilder
    def initialize(sale)
      @sale = sale
      @setting = sale.store.company.dte_setting
    end

    def call
      {
        "Encabezado" => {
          "IdDoc"    => id_doc,
          "Emisor"   => emisor,
          "Receptor" => receptor,
          "Totales"  => totales
        },
        "Detalle"   => detalle,
        "Referencia" => referencia
      }.compact
    end

    private

    attr_reader :sale, :setting

    def id_doc
      doc = {
        "TipoDTE"  => Sale.document_types[sale.document_type],
        "FchEmis"  => sale.sold_on.to_s
      }
      # Con folio propio se envia el que ya reservamos; si lo asigna el
      # proveedor, se omite y llega en la respuesta.
      doc["Folio"] = sale.folio if sale.folio.present?
      doc
    end

    def emisor
      {
        "RUTEmisor"     => setting&.rut_emisor,
        "RznSocEmisor"  => setting&.razon_social,
        "GiroEmisor"    => setting&.giro,
        "Acteco"        => setting&.acteco,
        "DirOrigen"     => setting&.dir_origen,
        "CmnaOrigen"    => setting&.cmna_origen,
        "CdgSIISucur"   => setting&.cdg_sii_sucur
      }.compact
    end

    # Una boleta a consumidor final no lleva receptor identificado.
    def receptor
      customer = sale.customer
      return nil if customer.blank?

      {
        "RUTRecep"    => customer.rut,
        "RznSocRecep" => customer.name,
        "GiroRecep"   => customer.giro,
        "DirRecep"    => customer.address,
        "CorreoRecep" => customer.email
      }.compact
    end

    def totales
      {
        "MntNeto"  => sale.net_amount.to_i,
        "TasaIVA"  => (sale.tax_rate.to_f * 100).round(2),
        "IVA"      => sale.tax_amount.to_i,
        "MntExe"   => sale.exempt_amount.to_i,
        "MntTotal" => sale.total_amount.to_i
      }
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

    def detalle
      sale.sale_items.each_with_index.map do |item, index|
        line = {
          "NroLinDet" => index + 1,
          "NmbItem"   => item.product.name,
          "QtyItem"   => item.quantity,
          "PrcItem"   => item.unit_price.to_i,
          "MontoItem" => item.subtotal.to_i
        }
        # IndExe = 1 marca la linea como exenta de IVA.
        line["IndExe"] = 1 if item.tax_exempt
        line
      end
    end
  end
end
