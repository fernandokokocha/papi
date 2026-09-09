class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :mock_token, null: false

      t.timestamps
    end

    add_index :projects, :mock_token, unique: true
  end
end
