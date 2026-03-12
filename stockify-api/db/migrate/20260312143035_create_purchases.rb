class CreatePurchases < ActiveRecord::Migration[7.1]
  def change
    create_table :purchases do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :store, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 1
      t.string :reference, null: false
      t.date :received_on, null: false
      t.decimal :total_amount, precision: 12, scale: 2, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :purchases, :reference, unique: true
  end
end
