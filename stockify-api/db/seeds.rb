puts "Cargando workspace demo de Stockery..."

[
  SaleItem, Sale, PurchaseItem, Purchase,
  InventoryAdjustment, InventoryLevel,
  Product, Supplier, Store,
  UserPermission, User,
  RolePermission, Permission,
  Company
].each(&:delete_all)

# ─── Compañía demo ────────────────────────────────────────────────────────────

company = Company.create!(name: "Demo Company", slug: "demo")

# ─── Permisos ─────────────────────────────────────────────────────────────────

PERMISSION_MATRIX = {
  "Productos" => {
    "products.view"   => "Ver catálogo de productos",
    "products.create" => "Crear y editar productos",
    "products.edit"   => "Editar productos existentes",
    "products.delete" => "Eliminar productos"
  },
  "Inventario" => {
    "inventory.view"   => "Ver niveles de inventario",
    "inventory.adjust" => "Realizar ajustes de inventario"
  },
  "Compras" => {
    "purchases.view"   => "Ver historial de compras",
    "purchases.create" => "Registrar nuevas compras"
  },
  "Ventas" => {
    "sales.view"   => "Ver historial de ventas",
    "sales.create" => "Registrar nuevas ventas"
  },
  "Reportes" => {
    "reports.view" => "Acceder a reportes operativos"
  },
  "Tiendas" => {
    "stores.view" => "Ver listado de tiendas"
  },
  "Proveedores" => {
    "suppliers.view"   => "Ver catálogo de proveedores",
    "suppliers.create" => "Crear proveedores",
    "suppliers.edit"   => "Editar proveedores",
    "suppliers.delete" => "Eliminar proveedores"
  },
  "Usuarios" => {
    "users.view"   => "Ver usuarios de la compañía",
    "users.create" => "Crear nuevos usuarios",
    "users.edit"   => "Editar usuarios y permisos",
    "users.delete" => "Desactivar usuarios"
  }
}.freeze

permissions = {}
PERMISSION_MATRIX.each do |category, entries|
  entries.each do |key, description|
    permissions[key] = Permission.create!(key: key, description: description, category: category)
  end
end

# ─── Matriz de permisos por rol ───────────────────────────────────────────────

ROLE_GRANTS = {
  "owner"   => permissions.keys,
  "admin"   => permissions.keys - ["users.delete"],
  "manager" => %w[
    products.view products.create products.edit
    inventory.view inventory.adjust
    purchases.view purchases.create
    sales.view sales.create
    reports.view
    stores.view
    suppliers.view suppliers.create suppliers.edit
  ],
  "clerk" => %w[
    products.view
    inventory.view
    purchases.view
    sales.view sales.create
    stores.view
  ]
}.freeze

ROLE_GRANTS.each do |role, keys|
  keys.each do |key|
    RolePermission.create!(role: role, permission: permissions[key])
  end
end

# ─── Usuarios ─────────────────────────────────────────────────────────────────

owner = User.create!(
  company: company,
  name: "Avery Chen",
  email: "owner@demo.stockery.app",
  role: :owner,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

admin = User.create!(
  company: company,
  name: "Avery Chen (Admin)",
  email: "admin@demo.stockery.app",
  role: :admin,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

manager = User.create!(
  company: company,
  name: "Nina Morales",
  email: "manager@demo.stockery.app",
  role: :manager,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

clerk = User.create!(
  company: company,
  name: "Leo Carter",
  email: "clerk@demo.stockery.app",
  role: :clerk,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

# ─── Tiendas ──────────────────────────────────────────────────────────────────

stores = [
  { name: "Santiago Principal", code: "STG", address: "Providencia 2401" },
  { name: "Las Condes",         code: "LCD", address: "Apoquindo 3200" },
  { name: "Bodega Norte",       code: "WHN", address: "Ruta 5 Norte KM 18" }
].map { |attrs| company.stores.create!(attrs) }

# ─── Proveedores ──────────────────────────────────────────────────────────────

suppliers = [
  { name: "Nimbus Devices",  contact_name: "Camila Reyes", email: "sales@nimbus.dev",     phone: "+56 9 5555 1001", notes: "Proveedor principal de electronica" },
  { name: "Metro Goods",     contact_name: "Jordan Price", email: "ops@metrogoods.io",    phone: "+56 9 5555 1002", notes: "Reposicion rapida" },
  { name: "Atlas Office",    contact_name: "Rafa Silva",   email: "hello@atlasoffice.co", phone: "+56 9 5555 1003", notes: "Embalaje y accesorios" }
].map { |attrs| company.suppliers.create!(attrs) }

# ─── Productos ────────────────────────────────────────────────────────────────

products = [
  { name: "Terminal POS Pulse",  sku: "POS-1001", description: "Terminal POS compacto con pagos NFC.",                         price: 499.0, low_stock_threshold: 8  },
  { name: "Scanner Halo",        sku: "SCN-2100", description: "Scanner inalambrico para mostradores de alto flujo.",           price: 129.0, low_stock_threshold: 12 },
  { name: "Impresora Atlas",     sku: "PRN-3300", description: "Impresora termica para lineas de caja.",                        price: 189.0, low_stock_threshold: 6  },
  { name: "Dock Retail",         sku: "DOC-4100", description: "Base de carga para dispositivos compartidos.",                  price: 89.0,  low_stock_threshold: 10 },
  { name: "Cajon Swift",         sku: "CSD-5200", description: "Cajon reforzado con gatillo electronico.",                      price: 149.0, low_stock_threshold: 5  },
  { name: "Pack Sensor Shelf",   sku: "SNS-6200", description: "Kit IoT para lectura inteligente de stock en gondola.",         price: 79.0,  low_stock_threshold: 15 },
  { name: "Etiquetas Stockery",  sku: "LBL-7100", description: "Etiquetas premium para marcaje de bodega.",                    price: 19.0,  low_stock_threshold: 40 },
  { name: "Tablet Mostrador",    sku: "TAB-8100", description: "Tablet de 11 pulgadas lista para kiosko y venta asistida.",    price: 359.0, low_stock_threshold: 7  }
].map { |attrs| company.products.create!(attrs) }

stores.each do |store|
  products.each do |product|
    InventoryLevel.create!(store: store, product: product, quantity: 0)
  end
end

# ─── Compras demo ─────────────────────────────────────────────────────────────

Purchases::Creator.new(
  user: admin,
  params: {
    supplier_id: suppliers[0].id,
    store_id: stores[0].id,
    received_on: 12.days.ago.to_date,
    items: [
      { product_id: products[0].id, quantity: 12, unit_cost: 340.0 },
      { product_id: products[1].id, quantity: 30, unit_cost: 72.0  },
      { product_id: products[2].id, quantity: 10, unit_cost: 112.0 }
    ]
  }
).call

Purchases::Creator.new(
  user: manager,
  params: {
    supplier_id: suppliers[1].id,
    store_id: stores[1].id,
    received_on: 8.days.ago.to_date,
    items: [
      { product_id: products[3].id, quantity: 24, unit_cost: 44.0 },
      { product_id: products[5].id, quantity: 60, unit_cost: 31.0 },
      { product_id: products[6].id, quantity: 200, unit_cost: 6.0 }
    ]
  }
).call

Purchases::Creator.new(
  user: admin,
  params: {
    supplier_id: suppliers[2].id,
    store_id: stores[2].id,
    received_on: 5.days.ago.to_date,
    items: [
      { product_id: products[4].id, quantity: 14, unit_cost: 95.0  },
      { product_id: products[7].id, quantity: 9,  unit_cost: 220.0 },
      { product_id: products[1].id, quantity: 20, unit_cost: 70.0  }
    ]
  }
).call

# ─── Ventas demo ──────────────────────────────────────────────────────────────

Sales::Creator.new(
  user: clerk,
  params: {
    store_id: stores[0].id,
    sold_on: 2.days.ago.to_date,
    customer_name: "Grupo Retail Aurora",
    items: [
      { product_id: products[0].id, quantity: 3, unit_price: 499.0 },
      { product_id: products[1].id, quantity: 9, unit_price: 129.0 }
    ]
  }
).call

Sales::Creator.new(
  user: manager,
  params: {
    store_id: stores[1].id,
    sold_on: 1.day.ago.to_date,
    customer_name: "Tiendas North Lane",
    items: [
      { product_id: products[3].id, quantity: 6,  unit_price: 89.0 },
      { product_id: products[5].id, quantity: 18, unit_price: 79.0 },
      { product_id: products[6].id, quantity: 45, unit_price: 19.0 }
    ]
  }
).call

Sales::Creator.new(
  user: clerk,
  params: {
    store_id: stores[2].id,
    sold_on: Date.current,
    customer_name: "Summit Supply",
    items: [
      { product_id: products[4].id, quantity: 10, unit_price: 149.0 },
      { product_id: products[7].id, quantity: 4,  unit_price: 359.0 }
    ]
  }
).call

# ─── Ajustes de inventario demo ───────────────────────────────────────────────

InventoryManager.adjust!(
  product: products[2], store: stores[0], user: manager,
  quantity_change: -3, reason: "audit",
  note: "Unidades danadas detectadas durante el conteo ciclico"
)

InventoryManager.adjust!(
  product: products[7], store: stores[2], user: admin,
  quantity_change: -2, reason: "display",
  note: "Asignacion para sala de exhibicion"
)

puts "Carga demo completada:"
puts "  Compania:    #{Company.count}"
puts "  Usuarios:    #{User.count}"
puts "  Tiendas:     #{Store.count}"
puts "  Proveedores: #{Supplier.count}"
puts "  Productos:   #{Product.count}"
puts "  Permisos:    #{Permission.count}"
puts "  Compras:     #{Purchase.count}"
puts "  Ventas:      #{Sale.count}"
puts ""
puts "Emails de acceso demo:"
puts "  owner@demo.stockery.app   / Stockify123!"
puts "  admin@demo.stockery.app   / Stockify123!"
puts "  manager@demo.stockery.app / Stockify123!"
puts "  clerk@demo.stockery.app   / Stockify123!"
