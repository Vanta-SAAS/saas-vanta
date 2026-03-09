require "rails_helper"

RSpec.describe Sunat::EmitDocumentService, type: :service do
  let(:enterprise) { create(:enterprise) }
  let(:user) { create(:user) }
  let(:customer_ruc) { create(:customer, enterprise: enterprise, tax_id_type: "ruc", tax_id: "20614625237") }
  let(:product) { create(:product, enterprise: enterprise, name: "Producto de prueba") }
  let!(:settings) { EnterpriseSetting.create!(enterprise: enterprise) }

  def setup_enterprise_for_billing
    # Step 1: Register enterprise
    register_service = Sunat::RegisterEnterpriseService.new(
      enterprise: enterprise,
      sol_user: "MODDATOS",
      sol_password: "MODDATOS"
    )
    register_service.call
    settings.reload

    # Step 2: Configure series
    client = Sunat::ApiClient.new(api_key: settings.sunat_api_key)
    client.update_client(serie_factura: "F001")

    # Step 3: Upload digital certificate
    cert_path = Rails.root.join("spec/fixtures/test_certificate.pfx")
    uploaded_file = Rack::Test::UploadedFile.new(cert_path, "application/x-pkcs12", true)
    upload_service = Sunat::UploadCertificateService.new(
      enterprise: enterprise,
      file: uploaded_file,
      password: "123456"
    )
    upload_service.call
    settings.reload
  end

  def create_confirmed_sale(customer)
    sale = create(:sale, :confirmed, enterprise: enterprise, customer: customer, seller: user, created_by: user)
    create(:sale_item, sale: sale, product: product, quantity: 2, unit_price: 100.0)
    sale.reload
    sale.save!
    sale
  end

  describe "#call" do
    context "full emission flow" do
      it "successfully emits a factura for a customer with RUC" do
        VCR.use_cassette("sunat_full_flow_factura") do
          setup_enterprise_for_billing

          settings.reload
          expect(settings.sunat_api_key).to be_present
          expect(settings.sunat_certificate_uploaded).to be true

          sale = create_confirmed_sale(customer_ruc)
          service = described_class.new(sale: sale)
          service.call

          expect(service).to be_valid
          expect(sale.reload.sunat_uuid).to be_present
          expect(sale.sunat_document_type).to eq("01")
          expect(sale.sunat_series).to start_with("F")
          expect(sale.sunat_status).to eq("ACCEPTED")
          expect(sale.sunat_cdr_description).to include("aceptada")
        end
      end
    end

    context "with invalid api_key" do
      before do
        settings.update!(sunat_api_key: "invalid_key", sunat_certificate_uploaded: true)
      end

      it "returns an authentication error from the microservice" do
        sale = create_confirmed_sale(customer_ruc)
        service = described_class.new(sale: sale)

        VCR.use_cassette("sunat_create_invoice_invalid_api_key") do
          service.call
        end

        expect(service).not_to be_valid
        expect(service.errors_message).to include("autenticacion")
      end
    end

    context "when microservice returns a JSON error detail" do
      before do
        settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: true)
      end

      it "shows the actual SUNAT error message, not a generic one" do
        sale = create_confirmed_sale(customer_ruc)
        service = described_class.new(sale: sale)
        billing_url = "#{Sunat::ApiClient::BASE_URL}/invoices"
        error_detail = "SOAP Fault [soap-env:Client.0111]: No tiene el perfil para enviar comprobantes electronicos"

        VCR.turned_off do
          WebMock.stub_request(:post, billing_url)
            .to_return(
              status: 502,
              headers: { "Content-Type" => "application/json" },
              body: { detail: error_detail }.to_json
            )

          service.call
        end

        expect(service).not_to be_valid
        expect(service.errors_message).to include("No tiene el perfil")
        expect(service.errors_message).not_to include("no está disponible")
      end
    end

    context "when microservice returns 502 with document data" do
      before do
        settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: true)
      end

      it "saves the document UUID for future retry" do
        sale = create_confirmed_sale(customer_ruc)
        service = described_class.new(sale: sale)

        document_data = {
          "uuid" => "doc-uuid-from-502",
          "status" => "ERROR",
          "series" => "F001",
          "correlative" => 7
        }

        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_invoice).and_raise(
          Sunat::ApiClient::ServerErrorWithDocument.new("Error en SUNAT: SOAP Fault", document_data)
        )

        service.call

        expect(service).not_to be_valid
        expect(sale.reload.sunat_uuid).to eq("doc-uuid-from-502")
        expect(sale.sunat_status).to eq("ERROR")
        expect(sale.sunat_series).to eq("F001")
        expect(sale.sunat_number).to eq(7)
      end
    end

    context "when billing service is unavailable" do
      before do
        settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: true)
      end

      it "returns a connection error" do
        sale = create_confirmed_sale(customer_ruc)
        service = described_class.new(sale: sale)
        billing_url = "#{Sunat::ApiClient::BASE_URL}/invoices"

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

  describe "validations" do
    it "fails when sale is not confirmed" do
      pending_sale = create(:sale, enterprise: enterprise, customer: customer_ruc, seller: user, created_by: user, status: "pending")
      service = described_class.new(sale: pending_sale)
      service.call

      expect(service).not_to be_valid
      expect(service.errors_message).to include("debe estar confirmada")
    end

    it "fails when sale already has a successfully emitted document" do
      sale = create_confirmed_sale(customer_ruc)
      sale.update!(sunat_uuid: "existing-uuid", sunat_status: "ACCEPTED")
      service = described_class.new(sale: sale)
      service.call

      expect(service).not_to be_valid
      expect(service.errors_message).to include("ya tiene un comprobante emitido")
    end

    it "allows retry when sale has a rejected document" do
      settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: true)
      sale = create_confirmed_sale(customer_ruc)
      sale.update!(sunat_uuid: "existing-uuid", sunat_status: "REJECTED")

      retry_response = {
        "uuid" => "existing-uuid",
        "status" => "ACCEPTED",
        "series" => "F001",
        "correlative" => 5,
        "xml_signed" => "<xml>signed</xml>",
        "cdr_code" => "0",
        "cdr_description" => "La Factura fue aceptada",
        "hash" => "abc123",
        "qr_image" => "base64qr",
        "next_document_series" => "F001",
        "next_document_number" => 6
      }

      client = instance_double(Sunat::ApiClient)
      allow(Sunat::ApiClient).to receive(:new).and_return(client)
      allow(client).to receive(:retry_document).with("existing-uuid").and_return(retry_response)

      service = described_class.new(sale: sale)
      service.call

      expect(service).to be_valid
      expect(sale.reload.sunat_status).to eq("ACCEPTED")
    end

    it "allows retry when sale has an errored document" do
      settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: true)
      sale = create_confirmed_sale(customer_ruc)
      sale.update!(sunat_uuid: "existing-uuid", sunat_status: "ERROR")

      retry_response = {
        "uuid" => "existing-uuid",
        "status" => "ACCEPTED",
        "series" => "F001",
        "correlative" => 5,
        "xml_signed" => "<xml>signed</xml>",
        "cdr_code" => "0",
        "cdr_description" => "La Factura fue aceptada",
        "hash" => "abc123",
        "qr_image" => "base64qr"
      }

      client = instance_double(Sunat::ApiClient)
      allow(Sunat::ApiClient).to receive(:new).and_return(client)
      allow(client).to receive(:retry_document).with("existing-uuid").and_return(retry_response)

      service = described_class.new(sale: sale)
      service.call

      expect(service).to be_valid
      expect(sale.reload.sunat_status).to eq("ACCEPTED")
    end

    it "fails when enterprise is not registered with SUNAT" do
      sale = create_confirmed_sale(customer_ruc)
      service = described_class.new(sale: sale)
      service.call

      expect(service).not_to be_valid
      expect(service.errors_message).to include("no esta registrada en el servicio SUNAT")
    end

    it "fails when enterprise has no digital certificate" do
      settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: false)
      sale = create_confirmed_sale(customer_ruc)
      service = described_class.new(sale: sale)
      service.call

      expect(service).not_to be_valid
      expect(service.errors_message).to include("no tiene certificado digital")
    end

    it "fails when customer has no document" do
      settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: true)
      customer_no_doc = create(:customer, :no_document, enterprise: enterprise)
      sale_no_doc = create(:sale, :confirmed, enterprise: enterprise, customer: customer_no_doc, seller: user, created_by: user)
      service = described_class.new(sale: sale_no_doc)
      service.call

      expect(service).not_to be_valid
      expect(service.errors_message).to include("debe tener RUC o DNI")
    end
  end

  describe "invoice payload" do
    it "builds the correct payload for the microservice" do
      sale = create_confirmed_sale(customer_ruc)
      api_client = Sunat::ApiClient.new(api_key: "test_key")
      payload = api_client.send(:build_document_payload, sale, series_type: :factura)

      expect(payload[:customer_doc_type]).to eq("ruc")
      expect(payload[:customer_doc_number]).to eq("20614625237")
      expect(payload[:customer_name]).to eq(customer_ruc.name)
      expect(payload[:currency]).to eq("PEN")
      expect(payload[:items]).to be_an(Array)
      expect(payload[:items].first[:description]).to eq("Producto de prueba")
      expect(payload[:items].first[:quantity]).to eq(2.0)
      expect(payload[:items].first[:unit_price]).to eq(100.0)
      expect(payload[:items].first[:item_type]).to eq("product")
      expect(payload[:items].first[:tax_type]).to eq("gravado")
    end
  end
end
