class CreateEndpoints < ActiveRecord::Migration[8.0]
  def change
    create_table :endpoints do |t|
      t.integer :http_verb, null: false
      t.string :url, null: false
      t.references :version, null: false, foreign_key: true
      t.references :endpoint_root, polymorphic: true, index: true, null: false
      t.string :original_endpoint_root, null: false

      t.timestamps
    end
  end
end
