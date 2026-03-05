require 'rails_helper'

RSpec.describe Provider, type: :model do
  describe 'validations' do
    context 'name' do
      it 'requires name to be present' do
        provider = build(:provider, name: nil)
        expect(provider).not_to be_valid
        expect(provider.errors[:name]).to include("no puede estar vacio")
      end

      it 'allows valid name' do
        provider = build(:provider, name: 'Proveedor ABC')
        expect(provider).to be_valid
      end
    end

    context 'email' do
      it 'allows valid email format' do
        provider = build(:provider, email: 'test@example.com')
        expect(provider).to be_valid
      end

      it 'rejects invalid email format' do
        provider = build(:provider, email: 'invalid-email')
        expect(provider).not_to be_valid
        expect(provider.errors[:email]).to include("no es valido")
      end

      it 'allows blank email' do
        provider = build(:provider, email: nil)
        expect(provider).to be_valid
      end
    end

    context 'phone_number' do
      it 'allows valid 9-digit cellphone starting with 9' do
        provider = build(:provider, phone_number: '987654321')
        expect(provider).to be_valid
      end

      it 'allows valid cellphone with country code +51' do
        provider = build(:provider, phone_number: '+51987654321')
        expect(provider).to be_valid
      end

      it 'allows valid cellphone with country code 51' do
        provider = build(:provider, phone_number: '51987654321')
        expect(provider).to be_valid
      end

      it 'rejects invalid phone format' do
        provider = build(:provider, phone_number: '123456789')
        expect(provider).not_to be_valid
        expect(provider.errors[:base]).to include("El Número de teléfono debe tener cualquiera de los siguientes formatos: 987654321, +51987654321, 51987654321")
      end

      it 'rejects phone with wrong length' do
        provider = build(:provider, phone_number: '98765432')
        expect(provider).not_to be_valid
      end

      it 'allows blank phone' do
        provider = build(:provider, phone_number: nil)
        expect(provider).to be_valid
      end
    end

    context 'tax_id (RUC)' do
      it 'allows valid RUC starting with 10 (persona natural)' do
        provider = build(:provider, tax_id: '10123456789')
        expect(provider).to be_valid
      end

      it 'allows valid RUC starting with 20 (persona jurídica)' do
        provider = build(:provider, tax_id: '20123456789')
        expect(provider).to be_valid
      end

      it 'rejects RUC with wrong prefix' do
        provider = build(:provider, tax_id: '30123456789')
        expect(provider).not_to be_valid
        expect(provider.errors[:base]).to include("El RUC debe ser un número válido de 11 dígitos (empezar con 10 o 20)")
      end

      it 'rejects RUC with wrong length' do
        provider = build(:provider, tax_id: '101234567')
        expect(provider).not_to be_valid
      end

      it 'rejects RUC with non-numeric characters' do
        provider = build(:provider, tax_id: '10ABCDEFGHI')
        expect(provider).not_to be_valid
      end

      it 'allows blank tax_id' do
        provider = build(:provider, tax_id: nil)
        expect(provider).to be_valid
      end
    end
  end
end
