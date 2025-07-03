class CreateResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :responses do |t|
      t.string :code, null: false
      t.string :note, null: true
      t.references :endpoint, null: false, foreign_key: true

      t.timestamps
    end

    add_index :responses, [ :endpoint_id, :code ], unique: true
  end
end
