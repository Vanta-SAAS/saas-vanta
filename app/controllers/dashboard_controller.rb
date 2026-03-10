class DashboardController < ApplicationController
  def index
    return unless current_enterprise

    load_sales_data if ventas_enabled?
    load_quotes_data if cotizaciones_enabled?
    load_purchase_orders_data if compras_enabled?
    load_credit_data if credito_enabled?
  end

  private

  def load_sales_data
    @sales_count = current_enterprise.sales.where(status: :confirmed).count
    @sales_pending = current_enterprise.sales.where(status: :pending).count

    @sales_total_month = current_enterprise.sales
      .where(status: :confirmed)
      .where(issue_date: Date.current.beginning_of_month..Date.current.end_of_month)
      .sum(:total)

    @monthly_sales = current_enterprise.sales
      .where(status: :confirmed)
      .where(issue_date: 6.months.ago.beginning_of_month..Date.current.end_of_month)
      .group_by_month(:issue_date, format: "%b %Y")
      .sum(:total)

    @recent_sales = current_enterprise.sales
      .includes(:customer, :seller)
      .order(created_at: :desc)
      .limit(5)

    @top_customers = current_enterprise.sales
      .where(status: :confirmed)
      .where(issue_date: Date.current.beginning_of_month..Date.current.end_of_month)
      .joins(:customer)
      .group("customers.name")
      .order("sum_total DESC")
      .limit(5)
      .sum(:total)
  end

  def load_quotes_data
    @quotes_pending = current_enterprise.customer_quotes.where(status: :pending).count

    @quotes_by_status = current_enterprise.customer_quotes
      .where(created_at: Date.current.beginning_of_month..Date.current.end_of_month.end_of_day)
      .group(:status)
      .count
      .transform_keys { |k| I18n.t("statuses.customer_quotes.#{k}", default: k.humanize) }

    @recent_quotes = current_enterprise.customer_quotes
      .includes(:customer)
      .order(created_at: :desc)
      .limit(5)
  end

  def load_purchase_orders_data
    @po_pending = current_enterprise.purchase_orders.where(status: :pending).count
  end

  def load_credit_data
    @upcoming_installments = SaleInstallment
      .joins(sale: :enterprise)
      .where(sales: { enterprise_id: current_enterprise.id, status: :confirmed })
      .where(status: :pending)
      .where(due_date: Date.current..30.days.from_now)
      .order(:due_date)
      .limit(5)
      .includes(sale: :customer)

    @total_pending_credit = SaleInstallment
      .joins(sale: :enterprise)
      .where(sales: { enterprise_id: current_enterprise.id, status: :confirmed })
      .where(status: :pending)
      .sum(:amount)
  end

  def ventas_enabled?
    current_enterprise.module_enabled?("ventas")
  end

  def cotizaciones_enabled?
    current_enterprise.module_enabled?("ventas.cotizaciones")
  end

  def compras_enabled?
    current_enterprise.module_enabled?("compras")
  end

  def credito_enabled?
    current_enterprise.module_enabled?("ventas.credito_clientes")
  end

  helper_method :ventas_enabled?, :cotizaciones_enabled?, :compras_enabled?, :credito_enabled?
end
