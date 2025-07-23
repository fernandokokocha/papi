class CreateVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :versions do |t|
      t.string :name, null: false
      t.integer :order, null: false
      t.references :project, null: true, foreign_key: true

      t.timestamps
    end
  end
end
