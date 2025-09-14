class CreateEndpoints < ActiveRecord::Migration[8.0]
  def change
    create_table :endpoints do |t|
      t.integer :http_verb, null: false
      t.string :path, null: false
      t.references :version, null: false, foreign_key: true
      t.string :output, null: false
      t.string :output_error, null: false
      t.string :note, null: true

      t.timestamps
    end
  end
end
