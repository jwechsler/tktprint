class CreateLineItems < ActiveRecord::Migration[4.2]
  def change
    create_table :line_items do |t|
      t.integer :order_id
      t.integer :quantity
      t.decimal :price, :precision=>6, :scale=>2
      t.timestamps
    end
  end
end
