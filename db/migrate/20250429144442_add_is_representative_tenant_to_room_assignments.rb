class AddIsRepresentativeTenantToRoomAssignments < ActiveRecord::Migration[8.0]
  def up
    add_column :room_assignments, :is_representative_tenant, :boolean, default: false

    # For each room, set the first tenant as the representative
    execute <<-SQL
      WITH first_tenants AS (
        SELECT DISTINCT ON (room_id) id
        FROM room_assignments
        WHERE active = true
        ORDER BY room_id, created_at ASC
      )
      UPDATE room_assignments
      SET is_representative_tenant = true
      WHERE id IN (SELECT id FROM first_tenants)
    SQL

    # Add a constraint to ensure only one representative tenant per room
    add_index :room_assignments, [:room_id],
              name: 'index_room_assignments_on_room_representative',
              unique: true,
              where: "active = true AND is_representative_tenant = true"
  end

  def down
    remove_index :room_assignments, name: 'index_room_assignments_on_room_representative'
    remove_column :room_assignments, :is_representative_tenant
  end
end
