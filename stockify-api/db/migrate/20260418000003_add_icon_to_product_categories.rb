class AddIconToProductCategories < ActiveRecord::Migration[7.1]
  def change
    add_column :product_categories, :icon, :string

    execute "UPDATE product_categories SET icon = 'HiSquares2X2' WHERE slug = 'general'"
  end
end
