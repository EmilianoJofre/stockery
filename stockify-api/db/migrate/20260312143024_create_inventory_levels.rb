class CreateInventoryLevels < ActiveRecord::Migration[7.1]
  def change
    create_table :inventory_levels do |t|
      t.references :product, null: false, foreign_key: true
      t.references :store, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 0

      t.timestamps
    end

    add_index :inventory_levels, [:product_id, :store_id], unique: true
  end
end
