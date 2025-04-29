class UpdateBuildingsWithLocationReferences < ActiveRecord::Migration[8.0]
  def change
    # Add new location reference columns
    add_reference :buildings, :country, foreign_key: true
    add_reference :buildings, :city, foreign_key: true
    add_reference :buildings, :district, foreign_key: true
    add_reference :buildings, :ward, foreign_key: true
    
    # Add street_address for the specific address portion
    add_column :buildings, :street_address, :string
    
    # Remove old address column (uncomment after data migration)
    # remove_column :buildings, :address, :string
  end
end
