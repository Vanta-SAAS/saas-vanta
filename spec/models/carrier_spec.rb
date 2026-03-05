require 'rails_helper'

RSpec.describe Carrier, type: :model do
  subject { build(:carrier) }

  describe 'associations' do
    it { should belong_to(:enterprise) }
  end

  describe 'validations' do
    it { should validate_presence_of(:ruc) }
    it { should validate_presence_of(:name) }

    it 'validates uniqueness of ruc scoped to enterprise' do
      enterprise = create(:enterprise)
      create(:carrier, enterprise: enterprise, ruc: "20123456789")
      duplicate = build(:carrier, enterprise: enterprise, ruc: "20123456789")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:ruc]).to include("ya esta registrado en esta empresa")
    end

    it 'allows same ruc in different enterprises' do
      create(:carrier, ruc: "20123456789")
      other = build(:carrier, ruc: "20123456789")
      expect(other).to be_valid
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(active: "active", inactive: "inactive").backed_by_column_of_type(:string) }
  end

  describe 'scopes' do
    it '.active returns only active carriers' do
      enterprise = create(:enterprise)
      active = create(:carrier, enterprise: enterprise, status: :active)
      create(:carrier, enterprise: enterprise, status: :inactive)
      expect(enterprise.carriers.active).to eq([ active ])
    end
  end

  describe '#combobox_display' do
    it 'returns name with ruc in parentheses' do
      carrier = build(:carrier, name: "Transportes SAC", ruc: "20123456789")
      expect(carrier.combobox_display).to eq("Transportes SAC (20123456789)")
    end
  end
end
