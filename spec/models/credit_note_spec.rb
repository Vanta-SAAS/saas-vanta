require "rails_helper"

RSpec.describe CreditNote, type: :model do
  let(:enterprise) { create(:enterprise) }
  let(:user) { create(:user) }
  let(:customer) { create(:customer, enterprise: enterprise) }
  let(:sale) { create(:sale, :confirmed, enterprise: enterprise, customer: customer, seller: user, created_by: user) }

  def build_cn(issue_date:)
    build(:credit_note, enterprise: enterprise, sale: sale, created_by: user, issue_date: issue_date)
  end

  describe "#voids_reference?" do
    it "is true for full annulment reasons" do
      %w[anulacion_de_la_operacion anulacion_por_error_en_el_ruc devolucion_total].each do |code|
        cn = build(:credit_note, reason_code: code)
        expect(cn.voids_reference?).to be(true), "expected #{code} to void"
      end
    end

    it "is false for partial reasons" do
      %w[disminucion_en_el_valor descuento_global descuento_por_item bonificacion otros_conceptos].each do |code|
        cn = build(:credit_note, reason_code: code)
        expect(cn.voids_reference?).to be(false), "expected #{code} to NOT void"
      end
    end
  end

  describe "issue_date validation" do
    it "is valid when issue_date is nil" do
      expect(build_cn(issue_date: nil)).to be_valid
    end

    it "is valid when issue_date is today" do
      expect(build_cn(issue_date: Date.current)).to be_valid
    end

    it "is valid up to 7 days in the past" do
      expect(build_cn(issue_date: Date.current - 7.days)).to be_valid
    end

    it "is invalid when issue_date is in the future" do
      cn = build_cn(issue_date: Date.current + 1.day)
      expect(cn).not_to be_valid
      expect(cn.errors[:issue_date].join).to include("futura")
    end

    it "is invalid when issue_date is more than 7 days in the past" do
      cn = build_cn(issue_date: Date.current - 8.days)
      expect(cn).not_to be_valid
      expect(cn.errors[:issue_date].join).to include("7 dias")
    end
  end
end
