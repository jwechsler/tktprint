class AddTicketClassAndTypeToTickets < ActiveRecord::Migration[6.1]
  def change
    add_column :tickets, :ticket_class, :string
    add_column :tickets, :type, :string
  end
end
