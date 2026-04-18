# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_04_17_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_companies_on_slug", unique: true
  end

  create_table "inventory_adjustments", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "store_id", null: false
    t.bigint "user_id", null: false
    t.integer "quantity_change", null: false
    t.string "reason", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_inventory_adjustments_on_product_id"
    t.index ["store_id"], name: "index_inventory_adjustments_on_store_id"
    t.index ["user_id"], name: "index_inventory_adjustments_on_user_id"
  end

  create_table "inventory_levels", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "store_id", null: false
    t.integer "quantity", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "store_id"], name: "index_inventory_levels_on_product_id_and_store_id", unique: true
    t.index ["product_id"], name: "index_inventory_levels_on_product_id"
    t.index ["store_id"], name: "index_inventory_levels_on_store_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.string "key", null: false
    t.string "description"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.string "sku", null: false
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "low_stock_threshold", default: 10, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id"], name: "index_products_on_company_id"
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "purchase_items", force: :cascade do |t|
    t.bigint "purchase_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_cost", precision: 10, scale: 2, null: false
    t.decimal "subtotal", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_purchase_items_on_product_id"
    t.index ["purchase_id"], name: "index_purchase_items_on_purchase_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.bigint "supplier_id", null: false
    t.bigint "store_id", null: false
    t.bigint "user_id", null: false
    t.integer "status", default: 1, null: false
    t.string "reference", null: false
    t.date "received_on", null: false
    t.decimal "total_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reference"], name: "index_purchases_on_reference", unique: true
    t.index ["store_id"], name: "index_purchases_on_store_id"
    t.index ["supplier_id"], name: "index_purchases_on_supplier_id"
    t.index ["user_id"], name: "index_purchases_on_user_id"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.string "role", null: false
    t.bigint "permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role", "permission_id"], name: "index_role_permissions_on_role_and_permission_id", unique: true
  end

  create_table "sale_items", force: :cascade do |t|
    t.bigint "sale_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "subtotal", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_sale_items_on_product_id"
    t.index ["sale_id"], name: "index_sale_items_on_sale_id"
  end

  create_table "sales", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.bigint "user_id", null: false
    t.integer "status", default: 1, null: false
    t.string "reference", null: false
    t.date "sold_on", null: false
    t.string "customer_name"
    t.decimal "total_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reference"], name: "index_sales_on_reference", unique: true
    t.index ["store_id"], name: "index_sales_on_store_id"
    t.index ["user_id"], name: "index_sales_on_user_id"
  end

  create_table "stores", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "address"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["code"], name: "index_stores_on_code", unique: true
    t.index ["company_id"], name: "index_stores_on_company_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "name", null: false
    t.string "contact_name"
    t.string "email"
    t.string "phone"
    t.text "notes"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id"], name: "index_suppliers_on_company_id"
  end

  create_table "user_permissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_user_permissions_on_permission_id"
    t.index ["user_id", "permission_id"], name: "index_user_permissions_on_user_id_and_permission_id", unique: true
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.integer "role", default: 2, null: false
    t.string "password_digest", null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.boolean "active", default: true, null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "inventory_adjustments", "products"
  add_foreign_key "inventory_adjustments", "stores"
  add_foreign_key "inventory_adjustments", "users"
  add_foreign_key "inventory_levels", "products"
  add_foreign_key "inventory_levels", "stores"
  add_foreign_key "products", "companies"
  add_foreign_key "purchase_items", "products"
  add_foreign_key "purchase_items", "purchases"
  add_foreign_key "purchases", "stores"
  add_foreign_key "purchases", "suppliers"
  add_foreign_key "purchases", "users"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "sale_items", "products"
  add_foreign_key "sale_items", "sales"
  add_foreign_key "sales", "stores"
  add_foreign_key "sales", "users"
  add_foreign_key "stores", "companies"
  add_foreign_key "suppliers", "companies"
  add_foreign_key "user_permissions", "permissions"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "users", "companies"
end
