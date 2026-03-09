require "rails_helper"

RSpec.describe Sunat::RegisterEnterpriseService, type: :service do
  let(:enterprise) { create(:enterprise) }

  describe "#call" do
    context "when registration is successful" do
      it "registers the enterprise and saves the api_key" do
        service = described_class.new(
          enterprise: enterprise,
          sol_user: "MODDATOS",
          sol_password: "MODDATOS"
        )

        VCR.use_cassette("sunat_register_enterprise_success") do
          service.call
        end

        expect(service).to be_valid
        expect(service.api_key).to be_present
        expect(enterprise.settings.sunat_api_key).to be_present
        expect(enterprise.settings.sunat_sol_user).to eq("MODDATOS")
        expect(enterprise.settings.sunat_sol_password).to eq("MODDATOS")
      end
    end

    context "when enterprise is already registered (RUC conflict)" do
      it "returns a duplicate error" do
        service = described_class.new(
          enterprise: enterprise,
          sol_user: "MODDATOS",
          sol_password: "MODDATOS"
        )
        billing_url = "#{Sunat::ApiClient::BASE_URL}/clients"

        VCR.turned_off do
          WebMock.stub_request(:post, billing_url)
            .to_return(
              status: 409,
              headers: { "Content-Type" => "application/json" },
              body: { detail: "A client with this RUC already exists" }.to_json
            )

          service.call
        end

        expect(service).not_to be_valid
        expect(service.errors_message).to include("A client with this RUC already exists")
      end
    end

    context "validations" do
      it "fails when enterprise has no RUC (informal)" do
        informal_enterprise = create(:enterprise, tax_id: nil)
        service = described_class.new(
          enterprise: informal_enterprise,
          sol_user: "MODDATOS",
          sol_password: "MODDATOS"
        )
        service.call

        expect(service).not_to be_valid
        expect(service.errors_message).to include("Solo empresas formales")
      end

      it "fails when sol_user is missing" do
        service = described_class.new(
          enterprise: enterprise,
          sol_user: nil,
          sol_password: "password123"
        )
        service.call

        expect(service).not_to be_valid
        expect(service.errors_message).to include("Sol_user es requerido")
      end

      it "fails when sol_password is missing" do
        service = described_class.new(
          enterprise: enterprise,
          sol_user: "ADMINIST",
          sol_password: nil
        )
        service.call

        expect(service).not_to be_valid
        expect(service.errors_message).to include("Sol_password es requerido")
      end
    end

    context "when billing service is unavailable" do
      it "returns a connection error" do
        service = described_class.new(
          enterprise: enterprise,
          sol_user: "MODDATOS",
          sol_password: "MODDATOS"
        )
        billing_url = "#{Sunat::ApiClient::BASE_URL}/clients"

        VCR.turned_off do
          WebMock.stub_request(:post, billing_url)
            .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

          service.call
        end

        expect(service).not_to be_valid
        expect(service.errors_message).to include("No se pudo conectar al servicio de facturacion")
      end
    end
  end
end
