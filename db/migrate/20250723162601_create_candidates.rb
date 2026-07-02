class CreateCandidates < ActiveRecord::Migration[8.0]
  def change
    create_table :candidates do |t|
      t.string :name
      t.integer :order
      t.references :project, null: false, foreign_key: true
      t.string :aasm_state, null: false, default: "open"
      t.references :base_version, null: true, foreign_key: { to_table: :versions }
      t.references :author, null: true, foreign_key: { to_table: :users }
      t.references :decided_by, null: true, foreign_key: { to_table: :users }
      t.datetime :decided_at, null: true

      t.timestamps
    end

    add_reference :versions, :candidate, foreign_key: true, null: true
  end
end
