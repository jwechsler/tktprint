class AddReprintCountToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :reprint_count, :integer, :default=>0
  end
end
