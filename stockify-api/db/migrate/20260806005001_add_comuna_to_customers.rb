class AddComunaToCustomers < ActiveRecord::Migration[7.1]
  # El SII exige `CmnaRecep` en una factura: verificado contra la API de
  # OpenFactura, que responde "Faltan los campos: CmnaRecep" si se omite.
  # No aplica a la boleta, que no identifica domicilio del receptor.
  def change
    add_column :customers, :comuna, :string
  end
end
