class CreateCustomers < ActiveRecord::Migration[7.1]
  # Receptor del documento tributario. Una factura exige identificar al receptor
  # (RUT, razon social, giro); una boleta normalmente no.
  #
  # Reemplaza el `sales.customer_name` de texto libre, que ademas impedia
  # cualquier analisis por cliente.
  def change
    create_table :customers do |t|
      t.references :company, null: false, foreign_key: true

      t.string :rut
      t.string :name, null: false
      t.string :giro
      t.string :email
      t.string :phone
      t.string :address
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    # El RUT es unico por compania, pero se permiten clientes sin RUT
    # (ventas de mostrador con nombre nomas).
    add_index :customers, %i[company_id rut], unique: true, where: "rut IS NOT NULL"
    add_index :customers, %i[company_id name]
  end
end
