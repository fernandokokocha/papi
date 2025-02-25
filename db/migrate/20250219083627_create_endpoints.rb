class CreateEndpoints < ActiveRecord::Migration[8.0]
  def change
    create_table :endpoints do |t|
      t.integer :http_verb
      t.string :url
      t.references :version, null: false, foreign_key: true

      t.timestamps
    end
  end
end
