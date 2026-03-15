require "rails_helper"

RSpec.describe ActivityLog, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:enterprise).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:controller_name) }
    it { is_expected.to validate_presence_of(:action_name) }
    it { is_expected.to validate_presence_of(:http_method) }
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_presence_of(:performed_at) }
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let(:enterprise) { create(:enterprise) }
    let(:log_attrs) do
      { controller_name: "sales", action_name: "index", http_method: "GET", path: "/sales", performed_at: Time.current }
    end

    describe ".recent" do
      it "orders by performed_at DESC" do
        old_log = ActivityLog.create!(log_attrs.merge(performed_at: 2.hours.ago))
        new_log = ActivityLog.create!(log_attrs.merge(performed_at: 1.minute.ago))

        expect(ActivityLog.recent.first).to eq(new_log)
        expect(ActivityLog.recent.last).to eq(old_log)
      end
    end

    describe ".for_enterprise" do
      it "filters by enterprise" do
        log_with = ActivityLog.create!(log_attrs.merge(enterprise: enterprise))
        _log_without = ActivityLog.create!(log_attrs)

        expect(ActivityLog.for_enterprise(enterprise)).to eq([ log_with ])
      end
    end

    describe ".for_user" do
      it "filters by user" do
        log_with = ActivityLog.create!(log_attrs.merge(user: user))
        _log_without = ActivityLog.create!(log_attrs)

        expect(ActivityLog.for_user(user)).to eq([ log_with ])
      end
    end

    describe ".for_record" do
      it "filters by record polymorphic" do
        sale = create(:sale)
        log_sale = ActivityLog.create!(log_attrs.merge(record_type: "Sale", record_id: sale.id))
        _log_other = ActivityLog.create!(log_attrs.merge(record_type: "Product", record_id: 999))

        expect(ActivityLog.for_record(sale)).to eq([ log_sale ])
      end
    end

    describe ".by_controller" do
      it "filters by controller" do
        log_sales = ActivityLog.create!(log_attrs.merge(controller_name: "sales"))
        _log_products = ActivityLog.create!(log_attrs.merge(controller_name: "products"))

        expect(ActivityLog.by_controller("sales")).to eq([ log_sales ])
      end
    end

    describe ".by_action" do
      it "filters by action" do
        log_index = ActivityLog.create!(log_attrs.merge(action_name: "index"))
        _log_create = ActivityLog.create!(log_attrs.merge(action_name: "create"))

        expect(ActivityLog.by_action("index")).to eq([ log_index ])
      end
    end
  end

  describe "request_params" do
    it "stores JSON correctly" do
      log = ActivityLog.create!(
        controller_name: "sales",
        action_name: "create",
        http_method: "POST",
        path: "/sales",
        performed_at: Time.current,
        request_params: { "customer_id" => "1", "items" => [ { "product_id" => "5" } ] }
      )

      log.reload
      expect(log.request_params["customer_id"]).to eq("1")
      expect(log.request_params["items"].first["product_id"]).to eq("5")
    end
  end
end
