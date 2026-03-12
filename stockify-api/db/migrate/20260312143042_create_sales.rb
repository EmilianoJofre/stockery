class CreateSales < ActiveRecord::Migration[7.1]
  def change
    create_table :sales do |t|
      t.references :store, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 1
      t.string :reference, null: false
      t.date :sold_on, null: false
      t.string :customer_name
      t.decimal :total_amount, precision: 12, scale: 2, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :sales, :reference, unique: true
  end
end
