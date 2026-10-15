class CreatePrintBatches < ActiveRecord::Migration[6.1]
  def change
    create_table :print_batches do |t|
      t.string :batch_id, null: false, unique: true
      t.string :status, null: false, default: 'pending'
      t.integer :order_count, default: 0
      t.integer :printed_count, default: 0
      t.integer :error_count, default: 0
      t.text :error_details
      t.datetime :ready_at
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :print_batches, :batch_id, unique: true
    add_index :print_batches, :status
    add_index :print_batches, :created_at
  end
end
