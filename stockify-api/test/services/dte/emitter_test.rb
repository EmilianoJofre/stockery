require "test_helper"

module Dte
  class EmitterTest < ActiveSupport::TestCase
    setup do
      scenario = full_scenario
      @company = scenario[:company]
      @store   = scenario[:store]
      @user    = scenario[:user]
      @product = create_product(@company)
      stock!(product: @product, store: @store, user: @user, quantity: 100)
    end

    test "emitir reserva folio propio y encola la transmision" do
      sale = create_sale(company: @company, user: @user, product: @product)

      Emitter.new(sale).issue!

      assert_equal 1, sale.reload.folio
      assert_equal "queued", sale.sii_status
    end

    test "transmitir marca el documento como aceptado" do
      sale = create_sale(company: @company, user: @user, product: @product, issue: true)

      Emitter.new(sale).transmit!

      assert_equal "accepted", sale.reload.sii_status
      assert sale.sii_track_id.present?
    end

    test "retransmitir un documento aceptado es idempotente" do
      sale = create_sale(company: @company, user: @user, product: @product, issue: true)
      Emitter.new(sale).transmit!
      track = sale.reload.sii_track_id

      Emitter.new(sale).transmit!

      assert_equal track, sale.reload.sii_track_id
    end

    # Con folio del proveedor no se consume el CAF propio: llega en la respuesta.
    test "con estrategia de proveedor el folio llega al transmitir" do
      @company.dte_setting.update!(folio_strategy: "provider")
      caf = @company.caf_ranges.find_by(document_type: 39)
      sale = create_sale(company: @company.reload, user: @user, product: @product)

      Emitter.new(sale).issue!

      assert_nil sale.reload.folio
      assert_equal 1, caf.reload.next_folio, "no debe consumir folio propio"

      Emitter.new(sale).transmit!

      assert sale.reload.folio.present?
    end

    test "un rechazo definitivo marca el documento y no es reintentable" do
      sale = create_sale(company: @company, user: @user, product: @product, issue: true)
      # Se corrompe el total para que el proveedor lo rechace como el SII.
      sale.update_columns(total_amount: 99_999)

      error = assert_raises(TransmissionError) { Emitter.new(sale).transmit! }

      assert_not error.retryable?
      assert_equal "rejected", sale.reload.sii_status
    end

    test "una empresa sin configuracion no puede emitir" do
      @company.dte_setting.update!(active: false)
      sale = create_sale(company: @company.reload, user: @user, product: @product)

      error = assert_raises(TransmissionError) { Emitter.new(sale).issue! }

      assert_includes error.message, "no tiene configurada"
    end
  end

  class DteSettingTest < ActiveSupport::TestCase
    setup { @company = create_company }

    test "la api key se guarda cifrada, no en claro" do
      setting = create_dte_setting(@company, provider: "openfactura", api_key: "SECRETO-123")

      stored = ActiveRecord::Base.connection.select_value(
        "SELECT api_key_ciphertext FROM dte_settings WHERE id = #{setting.id}"
      )

      assert_equal "SECRETO-123", setting.reload.api_key
      assert_not_includes stored.to_s, "SECRETO-123"
    end

    test "un proveedor remoto exige api key" do
      setting = @company.build_dte_setting(provider: "openfactura")

      assert_not setting.valid?
      assert_includes setting.errors[:api_key].join, "obligatoria"
    end

    test "el proveedor simulado no exige api key" do
      assert @company.build_dte_setting(provider: "simulated").valid?
    end
  end
end
