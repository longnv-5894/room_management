class CreateUnlockRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :unlock_records do |t|
      t.references :smart_device, null: false, foreign_key: true
      t.datetime :time, null: false
      t.string :user_id
      t.string :user_name
      t.string :unlock_method
      t.boolean :success, default: true
      t.json :raw_data

      t.timestamps
    end

    add_index :unlock_records, :time
    add_index :unlock_records, :record_id, unique: true
  end
end
