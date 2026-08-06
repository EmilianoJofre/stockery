# Constructor de escenarios minimos.
#
# Se prefiere esto a fixtures porque el dominio tiene demasiadas dependencias
# encadenadas (compania -> tienda -> producto -> lote -> movimiento) y las
# fixtures obligarian a mantener ids cruzados a mano. Aca cada test pide solo
# lo que necesita.
module Scenario
  PASSWORD = "Stockify123!".freeze

  def create_company(name: "Test SpA")
    Company.create!(name: name, slug: "test-#{SecureRandom.hex(4)}")
  end

  def create_store(company, name: "Tienda Test")
    company.stores.create!(name: name, code: "T#{SecureRandom.hex(2).upcase}")
  end

  def create_user(company, role: :admin, name: "Usuario Test")
    company.users.create!(
      name: name,
      email: "#{role}-#{SecureRandom.hex(4)}@test.cl",
      role: role,
      password: PASSWORD,
      password_confirmation: PASSWORD
    )
  end

  def create_product(company, name: "Producto Test", price: 1_190, tax_exempt: false)
    company.products.create!(
      name: name,
      sku: "SKU-#{SecureRandom.hex(4).upcase}",
      price: price,
      tax_exempt: tax_exempt
    )
  end

  def create_dte_setting(company, **overrides)
    company.create_dte_setting!({
      provider: "simulated",
      environment: "sandbox",
      folio_strategy: "own_caf",
      rut_emisor: "76543210-K",
      razon_social: company.name,
      giro: "Comercio",
      acteco: "471100",
      dir_origen: "Av. Test 100",
      cmna_origen: "Santiago"
    }.merge(overrides))
  end

  def create_caf_range(company, document_type: 39, range_start: 1, range_end: 100)
    company.caf_ranges.create!(
      document_type: document_type,
      range_start: range_start,
      range_end: range_end,
      next_folio: range_start,
      expires_on: Date.current + 180
    )
  end

  def create_customer(company, rut: "76192083-9", comuna: "Providencia", **overrides)
    company.customers.create!({
      rut: rut,
      name: "Cliente Test",
      giro: "Comercio",
      comuna: comuna,
      address: "Calle Falsa 123"
    }.merge(overrides))
  end

  # Escenario completo listo para emitir documentos.
  def full_scenario(folio_strategy: "own_caf")
    company = create_company
    store   = create_store(company)
    user    = create_user(company)
    create_dte_setting(company, folio_strategy: folio_strategy)
    create_caf_range(company, document_type: 39)
    create_caf_range(company, document_type: 33, range_start: 500, range_end: 600)
    create_caf_range(company, document_type: 61, range_start: 900, range_end: 950)

    { company: company, store: store, user: user }
  end

  # Crea stock real (via lotes) para poder vender.
  def stock!(product:, store:, user:, quantity:, unit_cost: 100, expiry_date: nil, lot_code: nil)
    InventoryManager.receive!(
      product: product, store: store, user: user,
      quantity: quantity, unit_cost: unit_cost,
      expiry_date: expiry_date, lot_code: lot_code,
      reason: "purchase"
    )
  end

  def create_sale(company:, user:, product:, quantity: 1, unit_price: 1_190,
                  document_type: "boleta", customer: nil, issue: false, **extra)
    Sales::Creator.new(
      user: user,
      company: company,
      params: {
        document_type: document_type,
        status: "completed",
        customer_id: customer&.id,
        issue: issue,
        items: [{ product_id: product.id, quantity: quantity, unit_price: unit_price }]
      }.merge(extra)
    ).call
  end

  # Permisos necesarios para los tests de integracion, que pasan por authorize!.
  def grant_all_permissions!(role: "admin")
    keys = %w[
      products.view inventory.view inventory.adjust
      purchases.view purchases.create sales.view sales.create
      reports.view stores.view suppliers.view
      users.view billing.manage
    ]

    keys.each do |key|
      permission = Permission.find_or_create_by!(key: key) do |p|
        p.description = key
        p.category = key.split(".").first
      end
      RolePermission.find_or_create_by!(role: role, permission: permission)
    end
  end
end
