class BackfillOpeningInventoryLots < ActiveRecord::Migration[7.1]
  # A partir de ahora `inventory_levels` es cache derivado de la suma de lotes.
  # Para que esa invariante valga desde el minuto cero, el stock que ya existia
  # se convierte en un lote de saldo inicial por (producto, tienda).
  #
  # Sin vencimiento: el stock historico no tiene esa informacion y no se puede
  # inventar. Los lotes con vencimiento real empiezan con las proximas compras.
  OPENING_LOT_CODE = "SALDO-INICIAL".freeze

  def up
    execute <<~SQL
      INSERT INTO inventory_lots (
        company_id, product_id, store_id, lot_code, expiry_date, received_on,
        unit_cost, quantity_received, quantity_remaining, created_at, updated_at
      )
      SELECT
        products.company_id,
        levels.product_id,
        levels.store_id,
        '#{OPENING_LOT_CODE}',
        NULL,
        COALESCE(levels.created_at::date, CURRENT_DATE),
        COALESCE(
          (SELECT ROUND(AVG(items.unit_cost), 2)
             FROM purchase_items items
            WHERE items.product_id = levels.product_id),
          0
        ),
        levels.quantity,
        levels.quantity,
        NOW(),
        NOW()
      FROM inventory_levels levels
      JOIN products ON products.id = levels.product_id
      WHERE levels.quantity > 0
    SQL

    say "Lotes de saldo inicial creados: #{select_value("SELECT COUNT(*) FROM inventory_lots WHERE lot_code = '#{OPENING_LOT_CODE}'")}"
  end

  def down
    execute "DELETE FROM inventory_lots WHERE lot_code = '#{OPENING_LOT_CODE}'"
  end
end
