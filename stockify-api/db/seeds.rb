puts "Cargando workspace demo de Stockery..."

[
  SaleItem, Sale, PurchaseItem, Purchase,
  InventoryAdjustment, InventoryLevel,
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
  company: company,
  name: "Carlos Muñoz",
  email: "owner@demo.stockery.app",
  role: :owner,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

admin = User.create!(
  company: company,
  name: "Valentina Soto",
  email: "admin@demo.stockery.app",
  role: :admin,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

manager = User.create!(
  company: company,
  name: "Jorge Espinoza",
  email: "manager@demo.stockery.app",
  role: :manager,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

clerk = User.create!(
  company: company,
  name: "Camila Torres",
  email: "clerk@demo.stockery.app",
  role: :clerk,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

# ─── Tiendas ──────────────────────────────────────────────────────────────────

stores = [
  { name: "Local Principal", code: "PRI", address: "Av. Grecia 1240, Ñuñoa" },
  { name: "Sucursal Norte",  code: "NOR", address: "Recoleta 880, Recoleta" }
].map { |attrs| company.stores.create!(attrs) }

# ─── Proveedores ──────────────────────────────────────────────────────────────

suppliers = [
  { name: "Distribuidora Central", contact_name: "Pedro Álvarez",  email: "ventas@distcentral.cl",  phone: "+56 9 8100 1001", notes: "Proveedor principal abarrotes y bebidas" },
  { name: "Lácteos del Sur",       contact_name: "Ana González",   email: "pedidos@lacteossur.cl",  phone: "+56 9 8100 1002", notes: "Entrega martes y viernes" },
  { name: "Limpio Chile",          contact_name: "Roberto Pino",   email: "ventas@limpiochile.cl",  phone: "+56 9 8100 1003", notes: "Aseo hogar e higiene personal" }
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
CATEGORY_SEEDS.each do |attrs|
  cats[attrs[:slug]] = company.product_categories.create!(attrs)
end

# ─── Productos ────────────────────────────────────────────────────────────────

products = [
  # Despensa
  { name: "Arroz SOS 1kg",         sku: "ARR-001", description: "Arroz largo grano fino.",                    price:  1_490, low_stock_threshold: 20, product_category: cats["despensa"] },
  { name: "Fideos Carozzi 400g",   sku: "FID-001", description: "Fideos spaghetti N°5.",                      price:    990, low_stock_threshold: 20, product_category: cats["despensa"] },
  { name: "Aceite Cuisine 1L",     sku: "ACE-001", description: "Aceite vegetal mix.",                        price:  2_490, low_stock_threshold: 15, product_category: cats["despensa"] },
  { name: "Mayonesa Hellmann's 400g", sku: "MAY-001", description: "Mayonesa clásica.",                       price:  2_190, low_stock_threshold: 12, product_category: cats["despensa"] },
  # Bebidas
  { name: "Coca-Cola 1.5L",        sku: "COC-001", description: "Bebida gaseosa.",                           price:  1_890, low_stock_threshold: 24, product_category: cats["bebidas"] },
  { name: "Agua Cachantun 1.5L",   sku: "AGU-001", description: "Agua mineral sin gas.",                     price:    690, low_stock_threshold: 24, product_category: cats["bebidas"] },
  { name: "Jugo Watt's Naranja 1L", sku: "JUG-001", description: "Néctar natural naranja.",                  price:  1_290, low_stock_threshold: 18, product_category: cats["bebidas"] },
  # Snacks y Dulces
  { name: "Papas Fritas Lays 100g", sku: "PAP-001", description: "Papas fritas clásicas.",                   price:    990, low_stock_threshold: 30, product_category: cats["snacks"] },
  { name: "Galletas Oreo 176g",    sku: "GAL-001", description: "Galleta rellena cacao.",                    price:  1_590, low_stock_threshold: 20, product_category: cats["snacks"] },
  { name: "Chocolate Sahne-Nuss",  sku: "CHO-001", description: "Chocolate con avellanas.",                  price:  1_490, low_stock_threshold: 15, product_category: cats["snacks"] },
  # Lácteos y Huevos
  { name: "Leche Soprole 1L",      sku: "LEC-001", description: "Leche entera UHT.",                        price:  1_190, low_stock_threshold: 30, product_category: cats["lacteos"] },
  { name: "Yogurt Colun Natural 150g", sku: "YOG-001", description: "Yogurt batido natural.",               price:    590, low_stock_threshold: 20, product_category: cats["lacteos"] },
  { name: "Huevos Blancos Docena", sku: "HUE-001", description: "Huevos blancos tamaño L.",                 price:  3_490, low_stock_threshold: 10, product_category: cats["lacteos"] },
  # Carnes y Embutidos
  { name: "Jamón de Pavo Luncheon 100g", sku: "JAM-001", description: "Jamón de pavo laminado.",           price:  1_290, low_stock_threshold: 15, product_category: cats["carnes"] },
  { name: "Mortadela Super Pollo 100g",  sku: "MOR-001", description: "Mortadela clásica.",                price:    890, low_stock_threshold: 15, product_category: cats["carnes"] },
  # Limpieza del Hogar
  { name: "Detergente Omo 800g",   sku: "DET-001", description: "Detergente en polvo.",                     price:  3_990, low_stock_threshold: 12, product_category: cats["limpieza"] },
  { name: "Cloro Clorox 1L",       sku: "CLO-001", description: "Blanqueador multiuso.",                    price:  1_490, low_stock_threshold: 10, product_category: cats["limpieza"] },
  # Higiene Personal
  { name: "Papel Higiénico Elite 4u", sku: "PAP-HIG-001", description: "Papel higiénico doble hoja.",      price:  2_490, low_stock_threshold: 20, product_category: cats["higiene"] },
  { name: "Shampoo Head & Shoulders 200ml", sku: "SHA-001", description: "Shampoo anticaspa.",             price:  3_990, low_stock_threshold: 10, product_category: cats["higiene"] },
  # Mascotas
  { name: "Dog Chow Adulto 3kg",   sku: "DOG-001", description: "Alimento completo para perro adulto.",    price:  8_990, low_stock_threshold: 8,  product_category: cats["mascotas"] },
  # Ferretería y Varios
  { name: "Pilas Duracell AA x4",  sku: "PIL-001", description: "Pilas alcalinas AA.",                     price:  2_990, low_stock_threshold: 10, product_category: cats["ferreteria"] }
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
    received_on: 10.days.ago.to_date,
    items: [
      { product_id: products[0].id, quantity: 50, unit_cost:  900 },
      { product_id: products[1].id, quantity: 50, unit_cost:  600 },
      { product_id: products[4].id, quantity: 72, unit_cost: 1_100 },
      { product_id: products[5].id, quantity: 48, unit_cost:  400 },
      { product_id: products[7].id, quantity: 48, unit_cost:  550 }
    ]
  }
).call

Purchases::Creator.new(
  user: manager,
  params: {
    supplier_id: suppliers[1].id,
    store_id: stores[0].id,
    received_on: 6.days.ago.to_date,
    items: [
      { product_id: products[10].id, quantity: 60, unit_cost:  700 },
      { product_id: products[11].id, quantity: 48, unit_cost:  350 },
      { product_id: products[12].id, quantity: 20, unit_cost: 2_200 },
      { product_id: products[13].id, quantity: 30, unit_cost:  750 }
    ]
  }
).call

Purchases::Creator.new(
  user: admin,
  params: {
    supplier_id: suppliers[2].id,
    store_id: stores[1].id,
    received_on: 4.days.ago.to_date,
    items: [
      { product_id: products[15].id, quantity: 24, unit_cost: 2_400 },
      { product_id: products[16].id, quantity: 24, unit_cost:  900 },
      { product_id: products[17].id, quantity: 36, unit_cost: 1_500 },
      { product_id: products[18].id, quantity: 18, unit_cost: 2_500 }
    ]
  }
).call

# ─── Ventas demo ──────────────────────────────────────────────────────────────

Sales::Creator.new(
  user: clerk,
  params: {
    store_id: stores[0].id,
    sold_on: 3.days.ago.to_date,
    customer_name: nil,
    items: [
      { product_id: products[4].id,  quantity: 6,  unit_price: 1_890 },
      { product_id: products[7].id,  quantity: 10, unit_price:   990 },
      { product_id: products[0].id,  quantity: 8,  unit_price: 1_490 }
    ]
  }
).call

Sales::Creator.new(
  user: clerk,
  params: {
    store_id: stores[0].id,
    sold_on: 2.days.ago.to_date,
    customer_name: nil,
    items: [
      { product_id: products[10].id, quantity: 12, unit_price: 1_190 },
      { product_id: products[12].id, quantity: 4,  unit_price: 3_490 },
      { product_id: products[17].id, quantity: 6,  unit_price: 2_490 }
    ]
  }
).call

Sales::Creator.new(
  user: manager,
  params: {
    store_id: stores[1].id,
    sold_on: 1.day.ago.to_date,
    customer_name: nil,
    items: [
      { product_id: products[5].id,  quantity: 10, unit_price:   690 },
      { product_id: products[8].id,  quantity: 8,  unit_price: 1_590 },
      { product_id: products[19].id, quantity: 2,  unit_price: 8_990 }
    ]
  }
).call

# ─── Ajustes de inventario demo ───────────────────────────────────────────────

InventoryManager.adjust!(
  product: products[10], store: stores[0], user: manager,
  quantity_change: -4, reason: "audit",
  note: "Unidades vencidas retiradas en conteo cíclico"
)

InventoryManager.adjust!(
  product: products[12], store: stores[1], user: admin,
  quantity_change: 12, reason: "restock",
  note: "Reposición urgente fin de semana"
)

puts "Carga demo completada:"
puts "  Compania:    #{Company.count}"
puts "  Usuarios:    #{User.count}"
puts "  Tiendas:     #{Store.count}"
puts "  Proveedores: #{Supplier.count}"
puts "  Categorias:  #{ProductCategory.count}"
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
