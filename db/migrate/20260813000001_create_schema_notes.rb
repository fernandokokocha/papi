class CreateSchemaNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :schema_notes do |t|
      t.references :notable, null: false, polymorphic: true
      t.string :path, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :schema_notes, [ :notable_type, :notable_id, :path ], unique: true
  end
end
