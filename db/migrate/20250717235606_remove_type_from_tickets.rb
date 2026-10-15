class RemoveTypeFromTickets < ActiveRecord::Migration[6.1]
  def change
    remove_column :tickets, :type, :string
  end
end
