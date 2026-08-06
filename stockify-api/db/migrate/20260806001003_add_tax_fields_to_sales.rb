class AddTaxFieldsToSales < ActiveRecord::Migration[7.1]
  def change
    # `tax_exempt` marca productos sin IVA (ej. algunos servicios o alimentos
    # exentos). Se necesita a nivel de producto y como snapshot en la linea,
    # porque el flag del producto puede cambiar despues de emitir el documento.
    add_column :products, :tax_exempt, :boolean, null: false, default: false
    add_column :sale_items, :tax_exempt, :boolean, null: false, default: false

    change_table :sales do |t|
      # Codigo de tipo de documento del SII: 39 boleta, 33 factura, 61 nota de credito.
      t.integer :document_type, null: false, default: 39

      # Desglose tributario. total_amount (que ya existia) es el monto BRUTO:
      #   net_amount + tax_amount + exempt_amount == total_amount
      t.decimal :net_amount,    precision: 12, scale: 2, null: false, default: 0
      t.decimal :tax_amount,    precision: 12, scale: 2, null: false, default: 0
      t.decimal :exempt_amount, precision: 12, scale: 2, null: false, default: 0
      # Tasa aplicada, guardada por documento: el IVA cambia con el tiempo y un
      # documento historico debe conservar la tasa con que se emitio.
      t.decimal :tax_rate, precision: 5, scale: 4, null: false, default: 0.19

      t.integer :folio
      t.references :caf_range, foreign_key: true
      # Marca la emision. A partir de aca el documento es inmutable.
      t.datetime :issued_at

      t.integer :sii_status, null: false, default: 0
      t.string  :sii_track_id

      t.references :customer, foreign_key: true
    end

    # Un folio no se puede repetir dentro del mismo tipo de documento de una tienda.
    add_index :sales, %i[store_id document_type folio], unique: true, where: "folio IS NOT NULL"
    add_index :sales, :issued_at
  end
end
