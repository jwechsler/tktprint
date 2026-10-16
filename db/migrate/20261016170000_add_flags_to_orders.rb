class AddFlagsToOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :orders, :flags, :string
  end
end
