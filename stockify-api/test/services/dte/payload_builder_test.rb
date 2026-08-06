require "test_helper"

module Dte
  # Estas pruebas fijan las diferencias del esquema del SII que se descubrieron
  # transmitiendo documentos reales al ambiente de demostracion de OpenFactura.
  # No son detalles cosmeticos: cada una hacia que el documento fuera rechazado.
  class PayloadBuilderTest < ActiveSupport::TestCase
    setup do
      scenario = full_scenario
      @company = scenario[:company]
      @store   = scenario[:store]
      @user    = scenario[:user]
      @product = create_product(@company)
      stock!(product: @product, store: @store, user: @user, quantity: 100)
    end

    def payload_for(sale)
      PayloadBuilder.new(sale).call
    end

    # ─── Boleta ───────────────────────────────────────────────────────────────

    test "la boleta declara IndServicio" do
      sale = create_sale(company: @company, user: @user, product: @product)
      id_doc = payload_for(sale).dig("Encabezado", "IdDoc")

      assert_equal 39, id_doc["TipoDTE"]
      assert_equal 3, id_doc["IndServicio"]
    end

    test "la boleta usa RznSocEmisor y GiroEmisor, y no lleva Acteco" do
      sale = create_sale(company: @company, user: @user, product: @product)
      emisor = payload_for(sale).dig("Encabezado", "Emisor")

      assert emisor.key?("RznSocEmisor")
      assert emisor.key?("GiroEmisor")
      assert_not emisor.key?("Acteco"), "el esquema de boleta rechaza Acteco"
    end

    test "la boleta no lleva TasaIVA en los totales" do
      sale = create_sale(company: @company, user: @user, product: @product)

      assert_not payload_for(sale).dig("Encabezado", "Totales").key?("TasaIVA")
    end

    test "una boleta sin cliente declara el RUT de consumidor final" do
      sale = create_sale(company: @company, user: @user, product: @product)
      receptor = payload_for(sale).dig("Encabezado", "Receptor")

      assert_equal "66666666-6", receptor["RUTRecep"]
    end

    test "en boleta los montos son brutos, igual que el precio de gondola" do
      sale = create_sale(company: @company, user: @user, product: @product, unit_price: 11_900)
      totales = payload_for(sale).dig("Encabezado", "Totales")

      assert_equal 10_000, totales["MntNeto"]
      assert_equal 1_900, totales["IVA"]
      assert_equal 11_900, totales["MntTotal"]
      assert_equal 11_900, payload_for(sale)["Detalle"].first["PrcItem"]
    end

    # ─── Factura ──────────────────────────────────────────────────────────────

    test "la factura usa RznSoc y GiroEmis, y si lleva Acteco" do
      sale = create_sale(company: @company, user: @user, product: @product,
                         document_type: "factura", customer: create_customer(@company))
      emisor = payload_for(sale).dig("Encabezado", "Emisor")

      assert emisor.key?("RznSoc"), "la factura nombra distinto la razon social"
      assert emisor.key?("GiroEmis")
      assert emisor.key?("Acteco")
      assert_not emisor.key?("RznSocEmisor")
    end

    test "la factura declara la comuna del receptor" do
      customer = create_customer(@company, comuna: "Las Condes")
      sale = create_sale(company: @company, user: @user, product: @product,
                         document_type: "factura", customer: customer)

      assert_equal "Las Condes", payload_for(sale).dig("Encabezado", "Receptor", "CmnaRecep")
    end

    # En factura el SII calcula el IVA sobre el neto, asi que PrcItem debe ir
    # neto. Nuestros precios son brutos: se convierten por linea.
    test "en factura el precio unitario va neto" do
      sale = create_sale(company: @company, user: @user, product: @product,
                         document_type: "factura", customer: create_customer(@company),
                         unit_price: 11_900)
      payload = payload_for(sale)

      assert_equal 10_000, payload["Detalle"].first["PrcItem"]
      assert_equal 10_000, payload.dig("Encabezado", "Totales", "MntNeto")
      assert_equal 1_900, payload.dig("Encabezado", "Totales", "IVA")
      assert_equal 19, payload.dig("Encabezado", "Totales", "TasaIVA")
    end

    # ─── Lineas exentas ───────────────────────────────────────────────────────

    test "marca las lineas exentas con IndExe" do
      exento = create_product(@company, name: "Exento", tax_exempt: true)
      stock!(product: exento, store: @store, user: @user, quantity: 10)

      sale = Sales::Creator.new(user: @user, company: @company, params: {
        document_type: "boleta", status: "completed",
        items: [
          { product_id: @product.id, quantity: 1, unit_price: 11_900 },
          { product_id: exento.id, quantity: 1, unit_price: 1_000 }
        ]
      }).call

      assert_equal [nil, 1], payload_for(sale)["Detalle"].map { |l| l["IndExe"] }
      assert_equal 1_000, payload_for(sale).dig("Encabezado", "Totales", "MntExe")
    end

    # ─── Nota de credito ──────────────────────────────────────────────────────

    test "la nota de credito referencia el documento que corrige" do
      sale = create_sale(company: @company, user: @user, product: @product, issue: true)
      note = Sales::CreditNoteCreator.new(sale: sale, user: @user, params: { reason: "Anulacion" }).call

      referencia = payload_for(note)["Referencia"].first

      assert_equal 39, referencia["TpoDocRef"]
      assert_equal sale.folio, referencia["FolioRef"]
      assert_equal Sale::REFERENCE_CODES[:annul], referencia["CodRef"]
      assert_equal "Anulacion", referencia["RazonRef"]
    end

    test "una venta normal no lleva bloque Referencia" do
      sale = create_sale(company: @company, user: @user, product: @product)

      assert_nil payload_for(sale)["Referencia"]
    end
  end
end
