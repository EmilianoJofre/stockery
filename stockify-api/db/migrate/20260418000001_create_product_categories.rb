class CreateProductCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :product_categories do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :product_categories, [:company_id, :name], unique: true
    add_index :product_categories, [:company_id, :slug], unique: true
  end
end
