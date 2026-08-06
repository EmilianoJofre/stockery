class CreateInventoryLots < ActiveRecord::Migration[7.1]
  def change
    create_table :inventory_lots do |t|
      t.references :company, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :store,   null: false, foreign_key: true
      t.references :purchase_item, foreign_key: true

      # Numero de lote del proveedor. Opcional: no todos los productos lo traen.
      t.string :lot_code
      # NULL = producto no perecible. Es la columna que habilita "que va a vencer".
      t.date :expiry_date
      t.date :received_on, null: false

      # Costo de esta entrada puntual: permite valorizar el stock por lote (FIFO real)
      # en vez de depender de un costo promedio del producto.
      t.decimal :unit_cost, precision: 10, scale: 2, null: false, default: 0

      t.integer :quantity_received,  null: false, default: 0
      t.integer :quantity_remaining, null: false, default: 0

      t.timestamps
    end

    # Orden FEFO (First Expired, First Out): se consume primero lo que vence antes.
    # Los lotes sin vencimiento quedan al final via NULLS LAST.
    add_index :inventory_lots,
              %i[product_id store_id expiry_date received_on id],
              name: "index_inventory_lots_fefo"

    # Indice parcial: el picking solo mira lotes con saldo.
    add_index :inventory_lots,
              %i[product_id store_id],
              where: "quantity_remaining > 0",
              name: "index_inventory_lots_available"

    add_check_constraint :inventory_lots,
                         "quantity_received >= 0",
                         name: "chk_lots_received_non_negative"
    add_check_constraint :inventory_lots,
                         "quantity_remaining >= 0",
                         name: "chk_lots_remaining_non_negative"
    add_check_constraint :inventory_lots,
                         "quantity_remaining <= quantity_received",
                         name: "chk_lots_remaining_lte_received"
  end
end
