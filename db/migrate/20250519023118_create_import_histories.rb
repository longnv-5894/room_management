class CreateImportHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :import_histories do |t|
      t.references :building, null: false, foreign_key: true
      t.string :file_name
      t.datetime :import_date
      t.references :user, null: false, foreign_key: true
      t.string :status
      t.text :imported_count
      t.text :notes
      t.string :file_path
      t.text :import_params

      t.timestamps
    end
  end
end
