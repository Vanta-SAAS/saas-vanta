require "rails_helper"

RSpec.describe Sunat::EmitCreditNoteService, type: :service do
  let(:enterprise) { create(:enterprise) }
  let(:user) { create(:user) }
  let(:customer) { create(:customer, enterprise: enterprise, tax_id_type: "ruc", tax_id: "20614625237") }
  let(:product) { create(:product, enterprise: enterprise, name: "Producto de prueba") }
  let!(:settings) do
    EnterpriseSetting.create!(
      enterprise: enterprise,
      sunat_series_nota_credito_factura: "FC01",
      sunat_series_nota_credito_boleta: "BC01"
    )
  end

  let(:sale) do
    sale = create(:sale, :confirmed, enterprise: enterprise, customer: customer, seller: user, created_by: user)
    create(:sale_item, sale: sale, product: product, quantity: 2, unit_price: 100.0)
    sale.reload
    sale.save!
    create(:sunat_document,
      documentable: sale,
      sunat_uuid: "original-doc-uuid",
      sunat_status: "ACCEPTED",
      sunat_document_type: "01",
      sunat_series: "F001",
      sunat_number: 1
    )
    sale
  end

  let(:credit_note) do
    cn = create(:credit_note, enterprise: enterprise, sale: sale, created_by: user)
    create(:credit_note_item, credit_note: cn, description: "Producto de prueba", quantity: 2, unit_price: 100.0)
    cn.reload
    cn.save!
    cn
  end

  describe "#call" do
    context "validations" do
      it "fails when sale has no accepted SUNAT document" do
        sale.current_sunat_document.update!(sunat_status: "ERROR")
        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).not_to be_valid
        expect(service.errors_message).to include("comprobante aceptado")
      end

      it "fails when enterprise is not registered with SUNAT" do
        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).not_to be_valid
        expect(service.errors_message).to include("no esta registrada")
      end

      it "fails when enterprise has no certificate" do
        settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: false)
        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).not_to be_valid
        expect(service.errors_message).to include("certificado digital")
      end

      it "fails when credit note has no items" do
        empty_cn = create(:credit_note, enterprise: enterprise, sale: sale, created_by: user)
        service = described_class.new(credit_note: empty_cn)
        service.call

        expect(service).not_to be_valid
        expect(service.errors_message).to include("al menos un item")
      end
    end

    context "successful emission" do
      before do
        settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: true)
      end

      it "emits a credit note successfully" do
        response = {
          "uuid" => "cn-uuid-123",
          "status" => "ACCEPTED",
          "series" => "F001",
          "correlative" => 1,
          "xml_signed" => "<xml>signed</xml>",
          "cdr_code" => "0",
          "cdr_description" => "La Nota de Credito fue aceptada",
          "hash" => "abc123",
          "qr_image" => "base64qr"
        }

        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_credit_note).and_return(response)

        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).to be_valid
        credit_note.reload
        expect(credit_note.sunat_uuid).to eq("cn-uuid-123")
        expect(credit_note.sunat_status).to eq("ACCEPTED")
        expect(credit_note.status).to eq("emitted")
        expect(credit_note.sunat_document_type).to eq("07")
      end

      it "voids the sale's SUNAT document when credit note is accepted" do
        response = {
          "uuid" => "cn-uuid-void",
          "status" => "ACCEPTED",
          "series" => "F001",
          "correlative" => 1,
          "xml_signed" => "<xml>signed</xml>",
          "cdr_code" => "0",
          "cdr_description" => "Aceptada",
          "hash" => "abc",
          "qr_image" => "qr"
        }

        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_credit_note).and_return(response)

        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).to be_valid
        sale_doc = sale.sunat_documents.find_by(sunat_uuid: "original-doc-uuid")
        expect(sale_doc.voided).to be true
      end

      it "does not void the sale's SUNAT document for partial credit notes (disminucion_en_el_valor)" do
        credit_note.update!(reason_code: "disminucion_en_el_valor")

        response = {
          "uuid" => "cn-uuid-partial",
          "status" => "ACCEPTED",
          "series" => "F001",
          "correlative" => 1,
          "xml_signed" => "<xml>signed</xml>",
          "cdr_code" => "0",
          "cdr_description" => "Aceptada",
          "hash" => "abc",
          "qr_image" => "qr"
        }

        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_credit_note).and_return(response)

        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).to be_valid
        sale_doc = sale.sunat_documents.find_by(sunat_uuid: "original-doc-uuid")
        expect(sale_doc.voided).to be false
        expect(sale.reload.can_emit_credit_note?).to be true
      end

      it "emits NC against an explicitly referenced voided document (anulacion parcial + ajuste posterior)" do
        original_doc = sale.sunat_documents.find_by(sunat_uuid: "original-doc-uuid")
        original_doc.void!
        new_active_doc = create(:sunat_document,
          documentable: sale,
          sunat_uuid: "rectified-doc-uuid",
          sunat_status: "ACCEPTED",
          sunat_document_type: "01",
          sunat_series: "F001",
          sunat_number: 2
        )

        credit_note.update!(
          reason_code: "disminucion_en_el_valor",
          referenced_sunat_document: original_doc
        )

        response = {
          "uuid" => "cn-uuid-against-voided",
          "status" => "ACCEPTED",
          "series" => "FC01",
          "correlative" => 5,
          "xml_signed" => "<xml>signed</xml>",
          "cdr_code" => "0",
          "cdr_description" => "Aceptada",
          "hash" => "abc",
          "qr_image" => "qr"
        }

        payload = Sunat::ApiClient.new(api_key: "test").send(:build_credit_note_payload, credit_note)
        expect(payload[:reference_document_id]).to eq("original-doc-uuid")

        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_credit_note).and_return(response)

        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).to be_valid
        expect(new_active_doc.reload.voided).to be false
        expect(original_doc.reload.voided).to be true
      end
    end

    context "when microservice returns an error" do
      before do
        settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: true)
      end

      it "handles connection errors" do
        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_credit_note).and_raise(
          Sunat::ApiClient::Error.new("No se pudo conectar al servicio de facturacion")
        )

        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).not_to be_valid
        expect(service.errors_message).to include("No se pudo conectar")
      end

      it "saves document data on ServerErrorWithDocument" do
        document_data = {
          "uuid" => "cn-uuid-error",
          "status" => "ERROR",
          "series" => "F001",
          "correlative" => 2
        }

        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_credit_note).and_raise(
          Sunat::ApiClient::ServerErrorWithDocument.new("Error en SUNAT", document_data)
        )

        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).not_to be_valid
        credit_note.reload
        expect(credit_note.sunat_uuid).to eq("cn-uuid-error")
        expect(credit_note.sunat_status).to eq("ERROR")
        expect(credit_note.status).to eq("error")
      end
    end

    context "retry" do
      before do
        settings.update!(sunat_api_key: "some_key", sunat_certificate_uploaded: true)
        credit_note.update!(status: :error)
        create(:sunat_document,
          documentable: credit_note,
          sunat_uuid: "cn-uuid-retry",
          sunat_status: "ERROR"
        )
      end

      it "retries using the existing UUID" do
        retry_response = {
          "uuid" => "cn-uuid-retry",
          "status" => "ACCEPTED",
          "series" => "F001",
          "correlative" => 1,
          "xml_signed" => "<xml>signed</xml>",
          "cdr_code" => "0",
          "cdr_description" => "La Nota de Credito fue aceptada",
          "hash" => "abc123",
          "qr_image" => "base64qr"
        }

        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:retry_credit_note).with("cn-uuid-retry").and_return(retry_response)

        service = described_class.new(credit_note: credit_note)
        service.call

        expect(service).to be_valid
        credit_note.reload
        expect(credit_note.sunat_status).to eq("ACCEPTED")
        expect(credit_note.status).to eq("emitted")
      end
    end
  end

  describe "credit note payload" do
    it "builds the correct payload for the microservice" do
      api_client = Sunat::ApiClient.new(api_key: "test_key")
      payload = api_client.send(:build_credit_note_payload, credit_note)

      expect(payload[:reference_document_id]).to eq("original-doc-uuid")
      expect(payload[:reason_code]).to eq("anulacion_de_la_operacion")
      expect(payload[:description]).to eq("Anulacion de la venta")
      expect(payload[:items]).to be_an(Array)
      expect(payload[:items].first[:description]).to eq("Producto de prueba")
      expect(payload[:items].first[:quantity]).to eq(2.0)
      expect(payload[:items].first[:unit_price]).to eq(100.0)
      expect(payload[:items].first[:item_type]).to eq("product")
      expect(payload[:items].first[:tax_type]).to eq("gravado")
    end

    it "omits issue_date when blank" do
      api_client = Sunat::ApiClient.new(api_key: "test_key")
      payload = api_client.send(:build_credit_note_payload, credit_note)
      expect(payload).not_to have_key(:issue_date)
    end

    it "includes issue_date in ISO format when present" do
      credit_note.update!(issue_date: Date.current - 2.days)
      api_client = Sunat::ApiClient.new(api_key: "test_key")
      payload = api_client.send(:build_credit_note_payload, credit_note)
      expect(payload[:issue_date]).to eq((Date.current - 2.days).iso8601)
    end
  end
end
