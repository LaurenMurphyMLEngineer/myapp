class CreateReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :receipts do |t|
      t.string :merchant
      t.decimal :total
      t.date :purchased_on
      t.text :raw_text

      t.timestamps
    end
  end
end
