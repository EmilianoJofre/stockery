class BackfillSaleTaxBreakdown < ActiveRecord::Migration[7.1]
  # Las ventas existentes ya guardaban el monto BRUTO en total_amount, asi que el
  # desglose se deriva hacia atras: neto = redondeo(bruto / 1.19), IVA = bruto - neto.
  # Calcular el IVA como resta (en vez de neto * 0.19) garantiza que
  # neto + IVA == total exactamente, sin arrastre de redondeo.
  #
  # `issued_at` queda NULL a proposito: estas ventas nunca fueron DTE emitidos y
  # no tienen folio. Marcarlas como emitidas seria inventar un dato tributario.
  def up
    execute <<~SQL
      UPDATE sales
         SET tax_rate      = 0.19,
             document_type = 39,
             exempt_amount = 0,
             net_amount    = ROUND(total_amount / 1.19),
             tax_amount    = total_amount - ROUND(total_amount / 1.19)
    SQL

    # `customer_name` era texto libre: se promueve a clientes reales, sin RUT
    # (nunca se capturo), y se vincula la venta.
    execute <<~SQL
      INSERT INTO customers (company_id, name, active, created_at, updated_at)
      SELECT DISTINCT stores.company_id, sales.customer_name, TRUE, NOW(), NOW()
        FROM sales
        JOIN stores ON stores.id = sales.store_id
       WHERE sales.customer_name IS NOT NULL
         AND btrim(sales.customer_name) <> ''
    SQL

    execute <<~SQL
      UPDATE sales
         SET customer_id = customers.id
        FROM customers, stores
       WHERE stores.id = sales.store_id
         AND customers.company_id = stores.company_id
         AND customers.name = sales.customer_name
      SQL

    say "Ventas con desglose: #{select_value('SELECT COUNT(*) FROM sales')}"
    say "Clientes creados desde customer_name: #{select_value('SELECT COUNT(*) FROM customers')}"
  end

  def down
    execute "UPDATE sales SET customer_id = NULL"
    execute "DELETE FROM customers"
    execute <<~SQL
      UPDATE sales
         SET net_amount = 0, tax_amount = 0, exempt_amount = 0
    SQL
  end
end
