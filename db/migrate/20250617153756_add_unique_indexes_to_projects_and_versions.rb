class AddUniqueIndexesToProjectsAndVersions < ActiveRecord::Migration[8.0]
  def change
    add_index :projects, [ :group_id, :name ], unique: true
    add_index :versions, [ :project_id, :name ], unique: true
  end
end
