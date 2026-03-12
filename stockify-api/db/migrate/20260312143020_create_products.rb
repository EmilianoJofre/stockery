class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :low_stock_threshold, null: false, default: 10
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :products, :sku, unique: true
  end
end
