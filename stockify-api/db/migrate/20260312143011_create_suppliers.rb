class CreateSuppliers < ActiveRecord::Migration[7.1]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.string :contact_name
      t.string :email
      t.string :phone
      t.text :notes
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
