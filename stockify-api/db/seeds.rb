puts "Cargando workspace demo de Stockery..."

[
  SaleItem, Sale,
  InventoryMovement, InventoryLot, InventoryLevel,
  PurchaseItem, Purchase,
  DteSetting, CafRange, Customer,
  Product, ProductCategory, Supplier, Store,
  UserPermission, User,
  RolePermission, Permission,
  Company
].each(&:delete_all)

# ─── Compañía demo ────────────────────────────────────────────────────────────

company = Company.create!(name: "Minimarket El Sol", slug: "el-sol")

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
  company: company, name: "Carlos Muñoz",
  email: "owner@demo.stockery.app", role: :owner,
  password: "Stockify123!", password_confirmation: "Stockify123!"
)

admin = User.create!(
  company: company, name: "Valentina Soto",
  email: "admin@demo.stockery.app", role: :admin,
  password: "Stockify123!", password_confirmation: "Stockify123!"
)

manager = User.create!(
  company: company, name: "Jorge Espinoza",
  email: "manager@demo.stockery.app", role: :manager,
  password: "Stockify123!", password_confirmation: "Stockify123!"
)

clerk = User.create!(
  company: company, name: "Camila Torres",
  email: "clerk@demo.stockery.app", role: :clerk,
  password: "Stockify123!", password_confirmation: "Stockify123!"
)

# ─── Tienda principal ─────────────────────────────────────────────────────────

store = company.stores.create!(
  name: "Tienda Principal",
  code: "PRI",
  address: "Av. Grecia 1240, Ñuñoa"
)

# ─── Proveedores ──────────────────────────────────────────────────────────────

suppliers = [
  { name: "Distribuidora Central", contact_name: "Pedro Álvarez",  email: "ventas@distcentral.cl", phone: "+56 9 8100 1001", notes: "Abarrotes, bebidas y snacks" },
  { name: "Lácteos del Sur",       contact_name: "Ana González",   email: "pedidos@lacteossur.cl", phone: "+56 9 8100 1002", notes: "Lácteos, carnes frías y congelados" },
  { name: "Limpio Chile",          contact_name: "Roberto Pino",   email: "ventas@limpiochile.cl", phone: "+56 9 8100 1003", notes: "Higiene, limpieza y varios" }
].map { |attrs| company.suppliers.create!(attrs) }

# ─── Categorías de productos ──────────────────────────────────────────────────

CATEGORY_SEEDS = [
  { name: "Despensa",            slug: "despensa",        icon: "HiArchiveBox"        },
  { name: "Bebidas",             slug: "bebidas",         icon: "MdLocalDrink"        },
  { name: "Snacks y Dulces",     slug: "snacks",          icon: "HiSparkles"          },
  { name: "Lácteos y Huevos",    slug: "lacteos",         icon: "HiCircleStack"       },
  { name: "Carnes y Embutidos",  slug: "carnes",          icon: "HiFire"              },
  { name: "Frutas y Verduras",   slug: "frutas-verduras", icon: "RiLeafFill"          },
  { name: "Congelados",          slug: "congelados",      icon: "MdAcUnit"            },
  { name: "Panadería",           slug: "panaderia",       icon: "MdBakeryDining"      },
  { name: "Limpieza del Hogar",  slug: "limpieza",        icon: "MdCleaningServices"  },
  { name: "Higiene Personal",    slug: "higiene",         icon: "HiUserCircle"        },
  { name: "Bebés y Niños",       slug: "bebes",           icon: "MdChildCare"         },
  { name: "Mascotas",            slug: "mascotas",        icon: "MdPets"              },
  { name: "Ferretería y Varios", slug: "ferreteria",      icon: "HiWrenchScrewdriver" },
  { name: "General",             slug: "general",         icon: "HiSquares2X2"        }
].freeze

cats = {}
CATEGORY_SEEDS.each { |attrs| cats[attrs[:slug]] = company.product_categories.create!(attrs) }

# ─── Productos (2 por categoría) ──────────────────────────────────────────────

PRODUCT_CATALOG = [
  # Despensa
  { name: "Arroz SOS 1kg",              sku: "ARR-001", price:  1_490, threshold: 20, category: "despensa",        description: "Arroz largo grano fino." },
  { name: "Aceite Cuisine 1L",          sku: "ACE-001", price:  2_490, threshold: 15, category: "despensa",        description: "Aceite vegetal mix." },
  # Bebidas
  { name: "Coca-Cola 1.5L",             sku: "COC-001", price:  1_890, threshold: 24, category: "bebidas",         description: "Bebida gaseosa." },
  { name: "Agua Cachantun 1.5L",        sku: "AGU-001", price:    690, threshold: 24, category: "bebidas",         description: "Agua mineral sin gas." },
  # Snacks y Dulces
  { name: "Papas Fritas Lays 100g",     sku: "PAP-001", price:    990, threshold: 30, category: "snacks",          description: "Papas fritas clásicas." },
  { name: "Chocolate Sahne-Nuss 100g",  sku: "CHO-001", price:  1_490, threshold: 20, category: "snacks",          description: "Chocolate con avellanas." },
  # Lácteos y Huevos
  { name: "Leche Soprole 1L",           sku: "LEC-001", price:  1_190, threshold: 30, category: "lacteos",         description: "Leche entera UHT." },
  { name: "Huevos Blancos Docena",      sku: "HUE-001", price:  3_490, threshold: 10, category: "lacteos",         description: "Huevos blancos tamaño L." },
  # Carnes y Embutidos
  { name: "Jamón de Pavo 100g",         sku: "JAM-001", price:  1_290, threshold: 15, category: "carnes",          description: "Jamón de pavo laminado." },
  { name: "Mortadela 100g",             sku: "MOR-001", price:    890, threshold: 15, category: "carnes",          description: "Mortadela clásica." },
  # Frutas y Verduras
  { name: "Tomate 1kg",                 sku: "TOM-001", price:  1_190, threshold: 10, category: "frutas-verduras", description: "Tomate larga vida." },
  { name: "Limón Bolsa 1kg",            sku: "LIM-001", price:    890, threshold: 10, category: "frutas-verduras", description: "Limones de exportación." },
  # Congelados
  { name: "Helado Bresler Vainilla 1L", sku: "HEL-001", price:  3_490, threshold:  8, category: "congelados",      description: "Helado familiar vainilla." },
  { name: "Supremas de Pollo 500g",     sku: "SUP-001", price:  2_990, threshold: 10, category: "congelados",      description: "Supremas apanadas." },
  # Panadería
  { name: "Marraqueta 6 unidades",      sku: "MAR-001", price:    890, threshold: 10, category: "panaderia",       description: "Pan marraqueta fresco." },
  { name: "Pan Molde Ideal 550g",       sku: "PAN-001", price:  1_690, threshold: 12, category: "panaderia",       description: "Pan molde blanco." },
  # Limpieza del Hogar
  { name: "Detergente Omo 800g",        sku: "DET-001", price:  3_990, threshold: 12, category: "limpieza",        description: "Detergente en polvo." },
  { name: "Cloro Clorox 1L",            sku: "CLO-001", price:  1_490, threshold: 10, category: "limpieza",        description: "Blanqueador multiuso." },
  # Higiene Personal
  { name: "Papel Higiénico Elite 4u",   sku: "PAH-001", price:  2_490, threshold: 20, category: "higiene",         description: "Papel higiénico doble hoja." },
  { name: "Jabón Dove Barra 90g",       sku: "JAB-001", price:    990, threshold: 15, category: "higiene",         description: "Jabón hidratante." },
  # Bebés y Niños
  { name: "Pañales Pampers M x30",      sku: "PAN-BEB-001", price: 12_990, threshold: 5, category: "bebes",        description: "Pañales medianos." },
  { name: "Leche Nan 1 400g",           sku: "NAN-001", price:  8_990, threshold:  5, category: "bebes",           description: "Leche de inicio en polvo." },
  # Mascotas
  { name: "Dog Chow Adulto 3kg",        sku: "DOG-001", price:  8_990, threshold:  8, category: "mascotas",        description: "Alimento completo perro adulto." },
  { name: "Friskies Gato 1.5kg",        sku: "FRI-001", price:  5_490, threshold:  8, category: "mascotas",        description: "Alimento completo para gato." },
  # Ferretería y Varios
  { name: "Pilas Duracell AA x4",       sku: "PIL-001", price:  2_990, threshold: 10, category: "ferreteria",      description: "Pilas alcalinas AA." },
  { name: "Ampolleta LED 9W",           sku: "AMP-001", price:  1_990, threshold:  8, category: "ferreteria",      description: "Ampolleta LED rosca E27." },
  # General
  { name: "Encendedor",                 sku: "ENC-001", price:    490, threshold: 20, category: "general",         description: "Encendedor plástico." },
  { name: "Fósforos Caja x50",          sku: "FOS-001", price:    290, threshold: 30, category: "general",         description: "Caja de fósforos." }
].freeze

products = PRODUCT_CATALOG.map do |attrs|
  p = company.products.create!(
    name:                 attrs[:name],
    sku:                  attrs[:sku],
    price:                attrs[:price],
    low_stock_threshold:  attrs[:threshold],
    description:          attrs[:description],
    product_category:     cats[attrs[:category]]
  )
  InventoryLevel.create!(product: p, store: store, quantity: 0)
  p
end

# Índice para referenciar productos fácilmente
by_sku = products.index_by(&:sku)

# ─── Compras demo ─────────────────────────────────────────────────────────────

Purchases::Creator.new(
  user: admin,
  params: {
    supplier_id: suppliers[0].id,
    received_on: 14.days.ago.to_date,
    items: [
      { product_id: by_sku["ARR-001"].id, quantity: 60,  unit_cost:    900 },
      { product_id: by_sku["ACE-001"].id, quantity: 36,  unit_cost:  1_500 },
      { product_id: by_sku["COC-001"].id, quantity: 72,  unit_cost:  1_100 },
      { product_id: by_sku["AGU-001"].id, quantity: 96,  unit_cost:    400 },
      { product_id: by_sku["PAP-001"].id, quantity: 60,  unit_cost:    550 },
      { product_id: by_sku["CHO-001"].id, quantity: 48,  unit_cost:    850 },
      { product_id: by_sku["MAR-001"].id, quantity: 30,  unit_cost:    500 },
      { product_id: by_sku["PAN-001"].id, quantity: 30,  unit_cost:  1_000 }
    ]
  }
).call

Purchases::Creator.new(
  user: manager,
  params: {
    supplier_id: suppliers[1].id,
    received_on: 9.days.ago.to_date,
    items: [
      { product_id: by_sku["LEC-001"].id, quantity: 72,  unit_cost:    700 },
      { product_id: by_sku["HUE-001"].id, quantity: 30,  unit_cost:  2_200 },
      { product_id: by_sku["JAM-001"].id, quantity: 36,  unit_cost:    750 },
      { product_id: by_sku["MOR-001"].id, quantity: 36,  unit_cost:    500 },
      { product_id: by_sku["TOM-001"].id, quantity: 30,  unit_cost:    700 },
      { product_id: by_sku["LIM-001"].id, quantity: 24,  unit_cost:    500 },
      { product_id: by_sku["HEL-001"].id, quantity: 20,  unit_cost:  2_000 },
      { product_id: by_sku["SUP-001"].id, quantity: 24,  unit_cost:  1_800 }
    ]
  }
).call

Purchases::Creator.new(
  user: admin,
  params: {
    supplier_id: suppliers[2].id,
    received_on: 5.days.ago.to_date,
    items: [
      { product_id: by_sku["DET-001"].id, quantity: 24,  unit_cost:  2_400 },
      { product_id: by_sku["CLO-001"].id, quantity: 24,  unit_cost:    900 },
      { product_id: by_sku["PAH-001"].id, quantity: 48,  unit_cost:  1_500 },
      { product_id: by_sku["JAB-001"].id, quantity: 36,  unit_cost:    550 },
      { product_id: by_sku["PIL-001"].id, quantity: 24,  unit_cost:  1_800 },
      { product_id: by_sku["AMP-001"].id, quantity: 24,  unit_cost:  1_200 },
      { product_id: by_sku["ENC-001"].id, quantity: 60,  unit_cost:    250 },
      { product_id: by_sku["FOS-001"].id, quantity: 60,  unit_cost:    150 }
    ]
  }
).call

# ─── Ventas demo ──────────────────────────────────────────────────────────────

Sales::Creator.new(
  user: clerk,
  params: {
    sold_on: 4.days.ago.to_date,
    items: [
      { product_id: by_sku["COC-001"].id, quantity: 12, unit_price: 1_890 },
      { product_id: by_sku["PAP-001"].id, quantity: 10, unit_price:   990 },
      { product_id: by_sku["ARR-001"].id, quantity:  6, unit_price: 1_490 },
      { product_id: by_sku["LEC-001"].id, quantity:  8, unit_price: 1_190 }
    ]
  }
).call

Sales::Creator.new(
  user: clerk,
  params: {
    sold_on: 2.days.ago.to_date,
    customer_name: "Junta de Vecinos Grecia",
    items: [
      { product_id: by_sku["DET-001"].id, quantity:  6, unit_price: 3_990 },
      { product_id: by_sku["PAH-001"].id, quantity: 12, unit_price: 2_490 },
      { product_id: by_sku["AGU-001"].id, quantity: 24, unit_price:   690 }
    ]
  }
).call

Sales::Creator.new(
  user: manager,
  params: {
    sold_on: 1.day.ago.to_date,
    items: [
      { product_id: by_sku["HUE-001"].id, quantity:  4, unit_price: 3_490 },
      { product_id: by_sku["JAM-001"].id, quantity:  6, unit_price: 1_290 },
      { product_id: by_sku["CHO-001"].id, quantity:  8, unit_price: 1_490 },
      { product_id: by_sku["HEL-001"].id, quantity:  3, unit_price: 3_490 }
    ]
  }
).call

# ─── Ajustes de inventario demo ───────────────────────────────────────────────

InventoryManager.adjust!(
  product: by_sku["LEC-001"], store: store, user: manager,
  quantity_change: -4, reason: "audit",
  note: "Unidades vencidas retiradas en conteo cíclico"
)

InventoryManager.adjust!(
  product: by_sku["HEL-001"], store: store, user: admin,
  quantity_change: 6, reason: "restock",
  note: "Reposición urgente de congelados"
)

# ─── Lotes con vencimiento ────────────────────────────────────────────────────
# Entradas perecibles escalonadas para que el orden FEFO y la alerta de
# vencimiento sean observables en la demo.

[
  { sku: "LEC-001", days:  5, qty: 12, cost:   790, lot: "L-2608-A" },
  { sku: "LEC-001", days: 21, qty: 18, cost:   810, lot: "L-2608-B" },
  { sku: "JAM-001", days:  3, qty:  8, cost:   890, lot: "J-2608-A" },
  { sku: "JAM-001", days: 14, qty: 10, cost:   910, lot: "J-2608-B" },
  { sku: "HUE-001", days: 30, qty: 24, cost: 2_390, lot: "H-2608-A" },
  { sku: "HEL-001", days: -2, qty:  4, cost: 2_490, lot: "C-2607-X" }
].each do |entry|
  InventoryManager.receive!(
    product:     by_sku[entry[:sku]],
    store:       store,
    user:        manager,
    quantity:    entry[:qty],
    unit_cost:   entry[:cost],
    expiry_date: Date.current + entry[:days],
    lot_code:    entry[:lot],
    reason:      "restock",
    note:        entry[:days].negative? ? "Lote vencido pendiente de retiro" : "Lote perecible recibido"
  )
end

# ─── Documentos tributarios (DTE) ─────────────────────────────────────────────
# Rangos de folios como los que entrega el SII en un CAF. Son de demo: no
# corresponden a una autorizacion real.

[
  { type: 39, from: 1,   to: 500, label: "boleta electronica" },
  { type: 33, from: 100, to: 200, label: "factura electronica" },
  { type: 61, from: 1,   to: 50,  label: "nota de credito" }
].each do |caf|
  company.caf_ranges.create!(
    document_type: caf[:type],
    range_start:   caf[:from],
    range_end:     caf[:to],
    next_folio:    caf[:from],
    authorized_on: Date.current - 30,
    expires_on:    Date.current + 180
  )
end

# Emision electronica en modo simulado: permite recorrer el flujo completo sin
# certificado digital ni cuenta de proveedor. NO emite documentos validos.
company.create_dte_setting!(
  provider:       "simulated",
  environment:    "sandbox",
  folio_strategy: "own_caf",
  rut_emisor:     "76543210-K",
  razon_social:   company.name,
  giro:           "Venta al por menor en almacenes no especializados",
  acteco:         "471100",
  dir_origen:     "Av. Grecia 1240",
  cmna_origen:    "Ñuñoa"
)

# Clientes con RUT valido (digito verificador real), para poder emitir facturas.
[
  { rut: "76192083-9", name: "Comercial Los Andes SpA", giro: "Comercio al por menor",
    email: "pagos@losandes.cl", address: "Av. Providencia 1234, Providencia" },
  { rut: "5126663-3",  name: "Rosa Fuentes Miranda", giro: "Almacen de barrio",
    email: "rosa.fuentes@gmail.com", address: "Pasaje Los Lirios 45, La Florida" }
].each { |attrs| company.customers.create!(attrs) }

# Un producto exento de IVA, para que el desglose neto/IVA/exento sea observable.
by_sku["FOS-001"]&.update!(tax_exempt: true)

puts "Carga demo completada:"
puts "  Compania:    #{Company.count}"
puts "  Usuarios:    #{User.count}"
puts "  Tiendas:     #{Store.count}"
puts "  Proveedores: #{Supplier.count}"
puts "  Categorias:  #{ProductCategory.count}"
puts "  Productos:   #{Product.count} (#{Product.count / ProductCategory.count.to_f} por categoría)"
puts "  Permisos:    #{Permission.count}"
puts "  Compras:     #{Purchase.count}"
puts "  Ventas:      #{Sale.count}"
puts "  Clientes:    #{Customer.count}"
puts "  Rangos CAF:  #{CafRange.count}"
puts "  Lotes:       #{InventoryLot.count} (#{InventoryLot.perishable.count} con vencimiento)"
puts ""
puts "Emails de acceso demo:"
puts "  owner@demo.stockery.app   / Stockify123!"
puts "  admin@demo.stockery.app   / Stockify123!"
puts "  manager@demo.stockery.app / Stockify123!"
puts "  clerk@demo.stockery.app   / Stockify123!"
