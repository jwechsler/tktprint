class AddBatchFieldsToOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :orders, :batch_id, :string
    add_column :orders, :batch_sequence, :integer
    add_column :orders, :print_status, :string, default: 'unprinted'
    add_column :orders, :print_error, :text
    add_column :orders, :printed_at, :datetime

    add_index :orders, :batch_id
    add_index :orders, :print_status
    add_index :orders, [:batch_id, :batch_sequence]
  end
end
