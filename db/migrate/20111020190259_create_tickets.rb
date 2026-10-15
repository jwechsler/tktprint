class CreateTickets < ActiveRecord::Migration[4.2]
  def change
    create_table :tickets do |t|
      t.integer :order_id
      t.string :ticket_number
      t.string :status
      t.timestamps
    end
  end
end
