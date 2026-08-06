class RenameInventoryAdjustmentsToInventoryMovements < ActiveRecord::Migration[7.1]
  # La tabla ya registraba TODO movimiento de stock (compras y ventas incluidas,
  # via reason: "purchase" / "sale"), no solo ajustes manuales. El nombre nuevo
  # refleja lo que realmente es: el ledger append-only de inventario.
  def change
    rename_table :inventory_adjustments, :inventory_movements

    # Lote consumido/creado por este movimiento. Nullable: las filas historicas
    # anteriores a los lotes no tienen uno.
    add_reference :inventory_movements, :inventory_lot, foreign_key: true, index: true

    # Documento de origen (Sale / Purchase). Antes el vinculo era solo texto libre
    # en `note` ("Recibido por REF-123"), imposible de unir de forma confiable.
    add_reference :inventory_movements, :source, polymorphic: true, index: true

    # Costo unitario al momento del movimiento: permite valorizar salidas.
    add_column :inventory_movements, :unit_cost, :decimal, precision: 10, scale: 2

    add_index :inventory_movements,
              %i[product_id store_id created_at],
              name: "index_inventory_movements_on_product_store_time"

    add_check_constraint :inventory_movements,
                         "quantity_change <> 0",
                         name: "chk_movements_quantity_change_not_zero"
  end
end
