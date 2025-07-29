class CreateCandidates < ActiveRecord::Migration[8.0]
  def change
    create_table :candidates do |t|
      t.string :name
      t.integer :order
      t.references :project, null: false, foreign_key: true
      t.string :aasm_state, null: false, default: "open"

      t.timestamps
    end

    add_reference :versions, :candidate, foreign_key: true, null: true
  end
end
