require 'rails_helper'

RSpec.describe DispatchGuideItem, type: :model do
  subject { build(:dispatch_guide_item) }

  describe 'associations' do
    it { should belong_to(:dispatch_guide) }
    it { should belong_to(:product).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:quantity) }
    it { should validate_presence_of(:unit_code) }

    it 'validates quantity is greater than 0' do
      item = build(:dispatch_guide_item, quantity: 0)
      expect(item).not_to be_valid
    end

    it 'rejects negative quantity' do
      item = build(:dispatch_guide_item, quantity: -1)
      expect(item).not_to be_valid
    end

    it 'accepts valid quantity' do
      item = build(:dispatch_guide_item, quantity: 5.5)
      expect(item).to be_valid
    end
  end
end
