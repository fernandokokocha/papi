class CreateEndpointParams < ActiveRecord::Migration[8.0]
  def change
    create_table :endpoint_params do |t|
      t.string :name, null: false
      t.string :kind, null: false, default: "string"
      t.references :endpoint, null: false, foreign_key: true

      t.timestamps
    end

    add_index :endpoint_params, [ :endpoint_id, :name ], unique: true
  end
end
