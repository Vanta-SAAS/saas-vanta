class AddIssueDateToCreditNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :credit_notes, :issue_date, :date
  end
end
