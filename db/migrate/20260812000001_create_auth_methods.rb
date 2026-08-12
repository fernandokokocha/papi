class CreateAuthMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :auth_methods do |t|
      t.string :name, null: false
      t.string :kind, null: false, default: "bearer"
      t.string :note, null: false, default: ""
      t.references :version, null: false, foreign_key: true

      t.timestamps
    end

    add_index :auth_methods, [ :version_id, :name ], unique: true
  end
end
