class CreatePurchaseItems < ActiveRecord::Migration[7.1]
  def change
    create_table :purchase_items do |t|
      t.references :purchase, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :unit_cost, precision: 10, scale: 2, null: false
      t.decimal :subtotal, precision: 12, scale: 2, null: false

      t.timestamps
    end
  end
end
