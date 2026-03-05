require 'rails_helper'

RSpec.describe UserField, type: :model do
  subject { build(:user_field) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:field_type) }
    it { should validate_presence_of(:value) }

    it 'validates field_type inclusion' do
      field = build(:user_field, field_type: "invalid_type")
      expect(field).not_to be_valid
      expect(field.errors[:field_type]).to be_present
    end

    it 'accepts valid field types' do
      %w[driving_license_number doc_number doc_type].each do |type|
        field = build(:user_field, field_type: type)
        expect(field).to be_valid
      end
    end

    it 'validates uniqueness of field_type scoped to user' do
      user = create(:user)
      create(:user_field, user: user, field_type: "driving_license_number")
      duplicate = build(:user_field, user: user, field_type: "driving_license_number")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:field_type]).to include("ya existe para este usuario")
    end

    it 'allows same field_type for different users' do
      create(:user_field, field_type: "driving_license_number")
      other = build(:user_field, field_type: "driving_license_number")
      expect(other).to be_valid
    end
  end
end
