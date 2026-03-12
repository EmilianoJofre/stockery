puts "Seeding Stockify demo workspace..."

[SaleItem, Sale, PurchaseItem, Purchase, InventoryAdjustment, InventoryLevel, Product, Supplier, Store, User].each(&:delete_all)

admin = User.create!(
  name: "Avery Chen",
  email: "admin@demo.stockify.app",
  role: :admin,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

manager = User.create!(
  name: "Nina Morales",
  email: "manager@demo.stockify.app",
  role: :manager,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

clerk = User.create!(
  name: "Leo Carter",
  email: "clerk@demo.stockify.app",
  role: :clerk,
  password: "Stockify123!",
  password_confirmation: "Stockify123!"
)

stores = [
  { name: "Santiago Flagship", code: "STG", address: "Providencia 2401" },
  { name: "Las Condes", code: "LCD", address: "Apoquindo 3200" },
  { name: "Warehouse North", code: "WHN", address: "Ruta 5 Norte KM 18" }
].map { |attrs| Store.create!(attrs) }

suppliers = [
  { name: "Nimbus Devices", contact_name: "Camila Reyes", email: "sales@nimbus.dev", phone: "+56 9 5555 1001", notes: "Primary electronics supplier" },
  { name: "Metro Goods", contact_name: "Jordan Price", email: "ops@metrogoods.io", phone: "+56 9 5555 1002", notes: "Fast replenishment window" },
  { name: "Atlas Office", contact_name: "Rafa Silva", email: "hello@atlasoffice.co", phone: "+56 9 5555 1003", notes: "Packaging and accessories" }
].map { |attrs| Supplier.create!(attrs) }

products = [
  { name: "Pulse POS Terminal", sku: "POS-1001", description: "Compact retail POS device with NFC payments.", price: 499.0, low_stock_threshold: 8 },
  { name: "Halo Barcode Scanner", sku: "SCN-2100", description: "Wireless scanner for high-volume counters.", price: 129.0, low_stock_threshold: 12 },
  { name: "Atlas Receipt Printer", sku: "PRN-3300", description: "Thermal receipt printer for checkout lanes.", price: 189.0, low_stock_threshold: 6 },
  { name: "Retail Dock", sku: "DOC-4100", description: "Charging dock for shared handheld devices.", price: 89.0, low_stock_threshold: 10 },
  { name: "Swift Cash Drawer", sku: "CSD-5200", description: "Heavy-duty drawer with electronic trigger.", price: 149.0, low_stock_threshold: 5 },
  { name: "Shelf Sensor Pack", sku: "SNS-6200", description: "IoT shelf sensor kit for smart stock reads.", price: 79.0, low_stock_threshold: 15 },
  { name: "Stockify Labels", sku: "LBL-7100", description: "Premium adhesive labels for warehouse marking.", price: 19.0, low_stock_threshold: 40 },
  { name: "Counter Tablet", sku: "TAB-8100", description: "11-inch kiosk-ready tablet for assisted sales.", price: 359.0, low_stock_threshold: 7 }
].map { |attrs| Product.create!(attrs) }

stores.each do |store|
  products.each do |product|
    InventoryLevel.create!(store: store, product: product, quantity: 0)
  end
end

Purchases::Creator.new(
  user: admin,
  params: {
    supplier_id: suppliers[0].id,
    store_id: stores[0].id,
    received_on: 12.days.ago.to_date,
    items: [
      { product_id: products[0].id, quantity: 12, unit_cost: 340.0 },
      { product_id: products[1].id, quantity: 30, unit_cost: 72.0 },
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
      { product_id: products[4].id, quantity: 14, unit_cost: 95.0 },
      { product_id: products[7].id, quantity: 9, unit_cost: 220.0 },
      { product_id: products[1].id, quantity: 20, unit_cost: 70.0 }
    ]
  }
).call

Sales::Creator.new(
  user: clerk,
  params: {
    store_id: stores[0].id,
    sold_on: 2.days.ago.to_date,
    customer_name: "Aurora Retail Group",
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
    customer_name: "North Lane Stores",
    items: [
      { product_id: products[3].id, quantity: 6, unit_price: 89.0 },
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
    customer_name: "Summit Supply Co.",
    items: [
      { product_id: products[4].id, quantity: 10, unit_price: 149.0 },
      { product_id: products[7].id, quantity: 4, unit_price: 359.0 }
    ]
  }
).call

InventoryManager.adjust!(
  product: products[2],
  store: stores[0],
  user: manager,
  quantity_change: -3,
  reason: "audit",
  note: "Damaged units identified during cycle count"
)

InventoryManager.adjust!(
  product: products[7],
  store: stores[2],
  user: admin,
  quantity_change: -2,
  reason: "display",
  note: "Showroom allocation"
)

puts "Seed complete:"
puts "  Users: #{User.count}"
puts "  Stores: #{Store.count}"
puts "  Products: #{Product.count}"
puts "  Purchases: #{Purchase.count}"
puts "  Sales: #{Sale.count}"
#   end
