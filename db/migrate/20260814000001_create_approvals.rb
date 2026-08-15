class CreateApprovals < ActiveRecord::Migration[8.0]
  def change
    create_table :approvals do |t|
      t.references :candidate, null: false
      t.references :user, null: false

      t.timestamps
    end

    add_index :approvals, [ :candidate_id, :user_id ], unique: true
  end
end
