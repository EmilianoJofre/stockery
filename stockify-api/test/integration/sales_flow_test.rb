require "test_helper"

# Recorre el ciclo tributario completo por HTTP: registrar -> emitir ->
# corregir. Es la prueba que cubre serializers, strong params y autorizacion,
# que las pruebas de servicio no tocan.
class SalesFlowTest < ActionDispatch::IntegrationTest
  setup do
    scenario = full_scenario
    @company = scenario[:company]
    @store   = scenario[:store]
    @user    = scenario[:user]
    @product = create_product(@company)
    stock!(product: @product, store: @store, user: @user, quantity: 100)
    grant_all_permissions!(role: "admin")

    login!(@user)
  end

  def login!(user)
    post "/api/v1/auth/login",
         params: { email: user.email, password: Scenario::PASSWORD },
         as: :json
    assert_response :success
  end

  def json
    JSON.parse(response.body)
  end

  test "registra una boleta y la emite en el mismo request" do
    post "/api/v1/sales", params: {
      sale: {
        document_type: "boleta", status: "completed", issue: true,
        items: [{ product_id: @product.id, quantity: 1, unit_price: 11_900 }]
      }
    }, as: :json

    assert_response :created
    sale = json["sale"]
    assert_equal "boleta", sale["document_type"]
    assert_equal 39, sale["document_code"]
    assert_equal 1, sale["folio"]
    assert sale["issued"]
    assert_equal 10_000.0, sale["net_amount"]
    assert_equal 1_900.0, sale["tax_amount"]
  end

  test "emitir dos veces devuelve 422 con un mensaje de dominio" do
    post "/api/v1/sales", params: {
      sale: { document_type: "boleta", status: "completed", issue: true,
              items: [{ product_id: @product.id, quantity: 1, unit_price: 1_190 }] }
    }, as: :json
    id = json["sale"]["id"]

    post "/api/v1/sales/#{id}/issue"

    assert_response :unprocessable_entity
    assert_includes json["error"], "ya fue emitido"
  end

  test "una factura sin comuna del receptor falla temprano" do
    sin_comuna = @company.customers.create!(rut: "76192083-9", name: "Sin comuna")

    post "/api/v1/sales", params: {
      sale: { document_type: "factura", status: "completed", customer_id: sin_comuna.id,
              items: [{ product_id: @product.id, quantity: 1, unit_price: 11_900 }] }
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes json["error"], "comuna"
  end

  test "emite una nota de credito que anula la venta y restituye el stock" do
    post "/api/v1/sales", params: {
      sale: { document_type: "boleta", status: "completed", issue: true,
              items: [{ product_id: @product.id, quantity: 6, unit_price: 1_190 }] }
    }, as: :json
    id = json["sale"]["id"]
    assert_equal 94, InventoryLevel.find_by(product: @product, store: @store).quantity

    post "/api/v1/sales/#{id}/credit_note", params: {
      credit_note: { reason: "Anulacion" }
    }, as: :json

    assert_response :created
    assert_equal Sale::REFERENCE_CODES[:annul], json["credit_note"]["reference_code"]
    assert json["sale"]["annulled"]
    assert_equal 100, InventoryLevel.find_by(product: @product, store: @store).quantity
  end

  test "el stock insuficiente devuelve 422 y no crea la venta" do
    post "/api/v1/sales", params: {
      sale: { document_type: "boleta", status: "completed",
              items: [{ product_id: @product.id, quantity: 999, unit_price: 1_190 }] }
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes json["error"], "Stock insuficiente"
    assert_equal 0, Sale.count
  end

  test "los lotes por vencer se consultan filtrados por horizonte" do
    stock!(product: @product, store: @store, user: @user, quantity: 5,
           expiry_date: Date.current + 3, lot_code: "PRONTO")
    stock!(product: @product, store: @store, user: @user, quantity: 5,
           expiry_date: Date.current + 200, lot_code: "LEJOS")

    get "/api/v1/inventory/lots", params: { expiring_within: 30 }

    assert_response :success
    assert_equal ["PRONTO"], json["lots"].map { |l| l["lot_code"] }
  end
end

class BillingAccessTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    create_store(@company)
    @admin = create_user(@company, role: :admin)
    @clerk = create_user(@company, role: :clerk)
    grant_all_permissions!(role: "admin")
  end

  def login!(user)
    post "/api/v1/auth/login",
         params: { email: user.email, password: Scenario::PASSWORD }, as: :json
  end

  test "un clerk no puede ver ni cambiar la configuracion de facturacion" do
    login!(@clerk)

    get "/api/v1/billing/settings"
    assert_response :forbidden

    put "/api/v1/billing/settings", params: { settings: { provider: "simulated" } }, as: :json
    assert_response :forbidden
  end

  test "un admin si puede, y la api key nunca vuelve al cliente" do
    login!(@admin)

    put "/api/v1/billing/settings", params: {
      settings: { provider: "openfactura", api_key: "SECRETA", razon_social: "Test" }
    }, as: :json

    assert_response :success
    settings = JSON.parse(response.body)["settings"]
    assert settings["api_key_configured"]
    assert_not settings.key?("api_key"), "la credencial no debe viajar al navegador"
  end

  test "enviar la api key vacia no la borra" do
    login!(@admin)
    put "/api/v1/billing/settings", params: {
      settings: { provider: "openfactura", api_key: "SECRETA" }
    }, as: :json

    put "/api/v1/billing/settings", params: {
      settings: { provider: "openfactura", api_key: "", giro: "Otro" }
    }, as: :json

    assert_response :success
    assert JSON.parse(response.body)["settings"]["api_key_configured"]
    assert_equal "SECRETA", @company.reload.dte_setting.api_key
  end
end
