class AddBillingPermission < ActiveRecord::Migration[7.1]
  # Se inserta por migracion y no solo en seeds porque las seeds no vuelven a
  # correr en instalaciones existentes: sin esto, ningun admin en produccion
  # podria abrir la configuracion de facturacion.
  KEY = "billing.manage".freeze

  def up
    execute <<~SQL
      INSERT INTO permissions (key, description, category, created_at, updated_at)
      SELECT '#{KEY}', 'Configurar facturacion electronica y folios', 'Facturacion', NOW(), NOW()
       WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE key = '#{KEY}')
    SQL

    # Solo owner y admin: la configuracion tributaria no es operacion diaria.
    execute <<~SQL
      INSERT INTO role_permissions (role, permission_id, created_at, updated_at)
      SELECT roles.role, permissions.id, NOW(), NOW()
        FROM (VALUES ('owner'), ('admin')) AS roles(role)
        CROSS JOIN permissions
       WHERE permissions.key = '#{KEY}'
         AND NOT EXISTS (
           SELECT 1 FROM role_permissions
            WHERE role_permissions.role = roles.role
              AND role_permissions.permission_id = permissions.id
         )
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM role_permissions
       WHERE permission_id IN (SELECT id FROM permissions WHERE key = '#{KEY}')
    SQL
    execute "DELETE FROM permissions WHERE key = '#{KEY}'"
  end
end
