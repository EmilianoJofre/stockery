class AddProductCategoryToProducts < ActiveRecord::Migration[7.1]
  def up
    add_column :products, :product_category_id, :bigint

    # Create a "General" category for every company that has products
    execute <<-SQL
      INSERT INTO product_categories (company_id, name, slug, active, created_at, updated_at)
      SELECT DISTINCT company_id, 'General', 'general', true, NOW(), NOW()
      FROM products
      ON CONFLICT (company_id, slug) DO NOTHING;
    SQL

    # Assign all existing products to their company's "General" category
    execute <<-SQL
      UPDATE products
      SET product_category_id = pc.id
      FROM product_categories pc
      WHERE products.company_id = pc.company_id
        AND pc.slug = 'general';
    SQL

    add_index :products, :product_category_id
    add_foreign_key :products, :product_categories
  end

  def down
    remove_foreign_key :products, :product_categories
    remove_index :products, :product_category_id
    remove_column :products, :product_category_id
  end
end
