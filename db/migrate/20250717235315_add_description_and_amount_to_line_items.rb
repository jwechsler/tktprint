class AddDescriptionAndAmountToLineItems < ActiveRecord::Migration[6.1]
  def change
    add_column :line_items, :description, :text
    add_column :line_items, :amount, :decimal
  end
end
