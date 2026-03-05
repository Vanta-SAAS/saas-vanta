require 'rails_helper'

RSpec.describe Vehicle, type: :model do
  subject { build(:vehicle) }

  describe 'associations' do
    it { should belong_to(:enterprise) }
  end

  describe 'validations' do
    it { should validate_presence_of(:plate) }

    it 'validates uniqueness of plate scoped to enterprise' do
      enterprise = create(:enterprise)
      create(:vehicle, enterprise: enterprise, plate: "ABC-123")
      duplicate = build(:vehicle, enterprise: enterprise, plate: "ABC-123")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:plate]).to include("ya esta registrada en esta empresa")
    end

    it 'allows same plate in different enterprises' do
      create(:vehicle, plate: "ABC-123")
      other_vehicle = build(:vehicle, plate: "ABC-123")
      expect(other_vehicle).to be_valid
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(active: "active", inactive: "inactive").backed_by_column_of_type(:string) }
  end

  describe 'scopes' do
    it '.active returns only active vehicles' do
      enterprise = create(:enterprise)
      active = create(:vehicle, enterprise: enterprise, status: :active)
      create(:vehicle, enterprise: enterprise, status: :inactive)
      expect(Vehicle.active).to eq([ active ])
    end
  end

  describe '#combobox_display' do
    it 'returns plate only when no brand or model' do
      vehicle = build(:vehicle, plate: "ABC-123", brand: nil, model: nil)
      expect(vehicle.combobox_display).to eq("ABC-123")
    end

    it 'includes brand when present' do
      vehicle = build(:vehicle, plate: "ABC-123", brand: "Toyota", model: nil)
      expect(vehicle.combobox_display).to eq("ABC-123 - Toyota")
    end

    it 'includes brand and model when both present' do
      vehicle = build(:vehicle, plate: "ABC-123", brand: "Toyota", model: "Hilux")
      expect(vehicle.combobox_display).to eq("ABC-123 - Toyota Hilux")
    end
  end
end
