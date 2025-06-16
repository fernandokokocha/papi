class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :name

      t.timestamps
    end

    add_reference :users, :group, foreign_key: true, null: false
    add_reference :projects, :group, foreign_key: true, null: false
  end
end
