class CreateDteSettings < ActiveRecord::Migration[7.1]
  # Configuracion de emision electronica por empresa.
  #
  # Es por empresa y no global porque Stockery es multi-tenant: cada tienda
  # factura con SU rut, SU certificado y SUS folios. No existe una credencial
  # unica de Stockery ante el SII.
  def change
    create_table :dte_settings do |t|
      t.references :company, null: false, foreign_key: true, index: { unique: true }

      # simulated = no sale a internet, para desarrollo y pruebas.
      t.string :provider, null: false, default: "simulated"
      t.string :environment, null: false, default: "sandbox"

      # Quien asigna el folio: nuestros CAF (software propio certificado) o el
      # proveedor (nos lo devuelve en la respuesta). Ver Dte::Emitter.
      t.string :folio_strategy, null: false, default: "own_caf"

      # Credencial del proveedor, cifrada en reposo.
      t.text :api_key_ciphertext

      # Datos del emisor exigidos por el SII en el encabezado del DTE.
      t.string :rut_emisor
      t.string :razon_social
      t.string :giro
      t.string :acteco
      t.string :dir_origen
      t.string :cmna_origen
      t.string :cdg_sii_sucur

      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
