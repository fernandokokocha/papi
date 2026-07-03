class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :candidate, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :parent, null: true, foreign_key: { to_table: :comments }
      t.text :body, null: false

      t.string :scope, null: false
      t.string :endpoint_path
      t.integer :endpoint_http_verb
      t.string :entity_name
      t.string :response_code
      t.string :part, null: false
      t.integer :line
      t.text :anchor_snapshot

      t.timestamps
    end
  end
end
