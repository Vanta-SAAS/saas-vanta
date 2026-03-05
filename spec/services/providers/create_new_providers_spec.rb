require 'rails_helper'

RSpec.describe Providers::CreateNewProviders do
  let(:enterprise) { create(:enterprise) }

  let(:valid_attributes) do
    [
      {
        name: Faker::Company.name,
        email: Faker::Internet.email,
        phone_number: "9#{Faker::Number.number(digits: 8)}",
        tax_id: "20#{Faker::Number.number(digits: 9)}"
      },
      {
        name: Faker::Company.name,
        email: Faker::Internet.email,
        phone_number: nil,
        tax_id: nil
      }
    ]
  end

  subject { described_class.new(records: providers_input, enterprise: enterprise) }

  describe '#call' do
    context 'when all providers are valid' do
      let(:providers_input) { valid_attributes }

      it 'creates all providers' do
        expect { subject.call }.to change(Provider, :count).by(2)
      end

      it 'sets the service as valid' do
        subject.call
        expect(subject).to be_valid
      end

      it 'has no errors' do
        subject.call
        expect(subject.errors).to be_empty
      end
    end

    context 'when some providers are invalid' do
      let(:invalid_provider_attributes) do
        {
          name: "",
          email: "invalid-email"
        }
      end

      let(:providers_input) { valid_attributes + [ invalid_provider_attributes ] }

      it 'creates only the valid providers' do
        expect { subject.call }.to change(Provider, :count).by(2)
      end

      it 'sets the service as invalid' do
        subject.call
        expect(subject).not_to be_valid
      end

      it 'collects errors for the invalid provider' do
        subject.call
        expect(subject.errors).not_to be_empty

        error_entry = subject.errors.find { |e| e[:name] == "" }
        expect(error_entry).to be_present
        expect(error_entry[:errors]).to include("Nombre no puede estar vacio")
      end
    end

    context 'when all providers are invalid' do
      let(:providers_input) do
        [
          { name: "" },
          { name: "" }
        ]
      end

      it 'creates no providers' do
        expect { subject.call }.not_to change(Provider, :count)
      end

      it 'sets the service as invalid' do
        subject.call
        expect(subject).not_to be_valid
      end
    end

    context 'edge cases' do
      context 'with empty provider list' do
        let(:providers_input) { [] }

        it 'is valid' do
          subject.call
          expect(subject).to be_valid
        end

        it 'creates no providers' do
          expect { subject.call }.not_to change(Provider, :count)
        end
      end
    end
  end
end
