class AddMultiTenancy < ActiveRecord::Migration[7.1]
  def up
    result = execute(<<~SQL)
      INSERT INTO companies (name, slug, active, created_at, updated_at)
      VALUES ('Demo Company', 'demo', true, NOW(), NOW())
      RETURNING id
    SQL
    company_id = result.first["id"]

    add_column :users, :company_id, :bigint
    add_column :stores, :company_id, :bigint
    add_column :suppliers, :company_id, :bigint
    add_column :products, :company_id, :bigint
    add_column :users, :active, :boolean, default: true, null: false

    execute("UPDATE users SET company_id = #{company_id}")
    execute("UPDATE stores SET company_id = #{company_id}")
    execute("UPDATE suppliers SET company_id = #{company_id}")
    execute("UPDATE products SET company_id = #{company_id}")

    change_column_null :users, :company_id, false
    change_column_null :stores, :company_id, false
    change_column_null :suppliers, :company_id, false
    change_column_null :products, :company_id, false

    add_foreign_key :users, :companies
    add_foreign_key :stores, :companies
    add_foreign_key :suppliers, :companies
    add_foreign_key :products, :companies

    add_index :users, :company_id
    add_index :stores, :company_id
    add_index :suppliers, :company_id
    add_index :products, :company_id
  end

  def down
    remove_foreign_key :users, :companies
    remove_foreign_key :stores, :companies
    remove_foreign_key :suppliers, :companies
    remove_foreign_key :products, :companies

    remove_column :users, :company_id
    remove_column :stores, :company_id
    remove_column :suppliers, :company_id
    remove_column :products, :company_id
    remove_column :users, :active
  end
end
