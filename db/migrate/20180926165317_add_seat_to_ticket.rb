class AddSeatToTicket < ActiveRecord::Migration[4.2]
  def change
    add_column :tickets, :seat, :string
  end
end
