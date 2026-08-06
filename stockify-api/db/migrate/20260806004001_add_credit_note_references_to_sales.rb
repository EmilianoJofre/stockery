class AddCreditNoteReferencesToSales < ActiveRecord::Migration[7.1]
  # Una nota de credito es un DTE que REFERENCIA a otro. El SII exige declarar
  # que documento corrige y por que (bloque Referencia del XML).
  def change
    change_table :sales do |t|
      # Documento corregido. Autorreferencia: la NC tambien es una Sale.
      t.references :references_sale, foreign_key: { to_table: :sales }

      # CodRef del SII: 1 anula, 2 corrige texto, 3 corrige montos.
      t.integer :reference_code
      t.string  :reference_reason

      # Se marca en el documento ORIGINAL cuando una NC lo anula. Es un campo
      # propio y no derivado para que excluirlo de los reportes sea un simple
      # WHERE, sin subconsulta.
      t.datetime :annulled_at
    end

    add_index :sales, :annulled_at
  end
end
