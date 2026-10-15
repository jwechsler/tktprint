class CreateOrders < ActiveRecord::Migration[4.2]
  def change
    create_table :orders do |t|
      t.string :last_name
      t.string :first_name
      t.string :performance_code
      t.string :venue
      t.string :theater
      t.string :title
      t.string :credit_1
      t.string :credit_2
      t.string :patron_code
      t.date :performance_date
      t.time :performance_time
      t.datetime :processed_on
      t.decimal :amount, :precision=>6, :scale=>2
      t.string :status, :default=>'Unprinted'
      t.integer :remote_id
      t.timestamps
    end
  end
end
