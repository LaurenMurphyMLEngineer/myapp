class AddCategoryToReceipts < ActiveRecord::Migration[8.1]
  def change
    add_column :receipts, :category, :string
  end
end
