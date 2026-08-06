class CreateCafRanges < ActiveRecord::Migration[7.1]
  # CAF (Codigo de Autorizacion de Folios): el SII entrega rangos de folios por
  # tipo de documento. Cada DTE emitido consume un folio de un rango vigente.
  #
  # Aca se modela el rango y su avance; la firma y el envio al SII quedan fuera
  # (dependen del certificado digital / proveedor).
  def change
    create_table :caf_ranges do |t|
      t.references :company, null: false, foreign_key: true

      # Codigo de tipo de documento del SII (39 boleta, 33 factura, 61 nota de credito...)
      t.integer :document_type, null: false

      t.integer :range_start, null: false
      t.integer :range_end,   null: false
      # Proximo folio a entregar. Cuando supera range_end el rango se agota.
      t.integer :next_folio,  null: false

      t.date :authorized_on
      t.date :expires_on
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :caf_ranges, %i[company_id document_type active]

    add_check_constraint :caf_ranges, "range_end >= range_start", name: "chk_caf_range_order"
    add_check_constraint :caf_ranges, "next_folio >= range_start", name: "chk_caf_next_folio_lower"
    # next_folio == range_end + 1 significa rango agotado, por eso el +1.
    add_check_constraint :caf_ranges, "next_folio <= range_end + 1", name: "chk_caf_next_folio_upper"
  end
end
