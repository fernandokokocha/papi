class CreateEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :entities do |t|
      t.string :name
      t.references :version, null: false, foreign_key: true
      t.string :root, null: false, default: ""

      t.timestamps
    end

    add_index :entities, [ :version_id, :name ], unique: true
  end
end
