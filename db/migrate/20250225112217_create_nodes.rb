class CreateNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :primitive_nodes do |t|
      t.integer :kind, null: false
      t.timestamps
    end

    create_table :object_nodes do |t|
      t.timestamps
    end

    create_table :object_attributes do |t|
      t.string :name, null: false
      t.integer :order, null: false
      t.references :value, polymorphic: true, index: true, null: false
      t.references :parent, null: false, foreign_key: { to_table: :object_nodes }

      t.timestamps
    end

    create_table :array_nodes do |t|
      t.references :value, polymorphic: true, index: true, null: false

      t.timestamps
    end
  end
end
