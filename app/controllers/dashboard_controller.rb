class DashboardController < ApplicationController
  def index
    return unless current_enterprise

    @sales_count = current_enterprise.sales.where(status: :confirmed).count
    @sales_pending = current_enterprise.sales.where(status: :pending).count
    @quotes_pending = current_enterprise.customer_quotes.where(status: :pending).count
    @po_pending = current_enterprise.purchase_orders.where(status: :pending).count

    @sales_total_month = current_enterprise.sales
      .where(status: :confirmed)
      .where(issue_date: Date.current.beginning_of_month..Date.current.end_of_month)
      .sum(:total)

    @recent_sales = current_enterprise.sales
      .includes(:customer, :seller)
      .order(created_at: :desc)
      .limit(5)

    @recent_quotes = current_enterprise.customer_quotes
      .includes(:customer)
      .order(created_at: :desc)
      .limit(5)
  end
end
