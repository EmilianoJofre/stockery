class CreateRbac < ActiveRecord::Migration[7.1]
  def change
    create_table :permissions do |t|
      t.string :key, null: false
      t.string :description
      t.string :category, null: false
      t.timestamps
    end
    add_index :permissions, :key, unique: true

    create_table :role_permissions do |t|
      t.string :role, null: false
      t.references :permission, null: false, foreign_key: true
      t.timestamps
    end
    add_index :role_permissions, [:role, :permission_id], unique: true

    create_table :user_permissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.timestamps
    end
    add_index :user_permissions, [:user_id, :permission_id], unique: true
  end
end
