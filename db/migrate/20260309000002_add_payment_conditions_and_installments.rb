class AddPaymentConditionsAndInstallments < ActiveRecord::Migration[8.0]
  def change
    # Payment condition for sales and customer quotes
    add_column :sales, :payment_condition, :string, null: false, default: "cash"
    add_index :sales, :payment_condition

    add_column :customer_quotes, :payment_condition, :string, null: false, default: "cash"
    add_index :customer_quotes, :payment_condition

    # Sale installments
    create_table :sale_installments do |t|
      t.references :sale, null: false, foreign_key: true
      t.integer :installment_number, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :due_date, null: false
      t.string :status, default: "pending", null: false
      t.date :paid_at
      t.timestamps
    end

    add_index :sale_installments, [ :sale_id, :installment_number ], unique: true

    # Customer quote installments
    create_table :customer_quote_installments do |t|
      t.references :customer_quote, null: false, foreign_key: true
      t.integer :installment_number, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :due_date, null: false
      t.timestamps
    end

    add_index :customer_quote_installments, [ :customer_quote_id, :installment_number ],
              unique: true, name: "idx_cq_installments_on_quote_and_number"
  end
end
