class CreatePayments < ActiveRecord::Migration[4.2]
  def change
    create_table :payments do |t|
      t.integer :order_id
      t.string :transaction_id
      t.decimal :amount, :precision=>6, :scale=>2
      t.string :payment_type
      t.timestamps
    end
  end
end
