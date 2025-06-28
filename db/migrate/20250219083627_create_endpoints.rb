class CreateEndpoints < ActiveRecord::Migration[8.0]
  def change
    create_table :endpoints do |t|
      t.integer :http_verb, null: false
      t.string :url, null: false
      t.references :version, null: false, foreign_key: true
      t.references :input, polymorphic: true, index: true, null: false
      t.references :output, polymorphic: true, index: true, null: false
      t.string :original_input_string, null: false
      t.string :original_output_string, null: false
      t.string :note, null: true

      t.timestamps
    end
  end
end
