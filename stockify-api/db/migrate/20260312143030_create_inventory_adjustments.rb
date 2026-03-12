class CreateInventoryAdjustments < ActiveRecord::Migration[7.1]
  def change
    create_table :inventory_adjustments do |t|
      t.references :product, null: false, foreign_key: true
      t.references :store, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :quantity_change, null: false
      t.string :reason, null: false
      t.text :note

      t.timestamps
    end
  end
end
