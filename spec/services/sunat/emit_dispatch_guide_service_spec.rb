require 'rails_helper'

RSpec.describe Sunat::EmitDispatchGuideService do
  let(:enterprise) { create(:enterprise) }
  let(:user) { create(:user) }
  let(:guide) { create(:dispatch_guide, enterprise: enterprise, created_by: user) }
  let!(:item) { create(:dispatch_guide_item, dispatch_guide: guide) }

  let(:settings) do
    enterprise.settings || enterprise.create_settings!
  end

  let(:api_response) do
    {
      "uuid" => SecureRandom.uuid,
      "status" => "ACCEPTED",
      "series" => "T001",
      "correlative" => 42,
      "xml_signed" => "<xml>signed</xml>",
      "cdr_code" => "0",
      "cdr_description" => "La Guia de Remision fue aceptada",
      "hash" => "abc123hash",
      "qr_image" => "base64qrdata",
      "next_document_series" => "T001",
      "next_document_number" => 43
    }
  end

  before do
    settings.update!(
      sunat_api_key: "test-api-key",
      sunat_certificate_uploaded: true
    )
  end

  subject { described_class.new(dispatch_guide: guide) }

  describe '#call' do
    context 'when all prerequisites are met' do
      before do
        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_dispatch_guide_remitente).and_return(api_response)
      end

      it 'emits the guide successfully' do
        subject.call
        expect(subject).to be_valid
      end

      it 'updates guide with SUNAT data' do
        subject.call
        guide.reload
        expect(guide.sunat_uuid).to eq(api_response["uuid"])
        expect(guide.sunat_status).to eq("ACCEPTED")
        expect(guide.sunat_document_type).to eq("09")
        expect(guide.sunat_series).to eq("T001")
        expect(guide.sunat_number).to eq(42)
        expect(guide.status).to eq("emitted")
      end

      it 'saves next document info for GRR' do
        subject.call
        settings.reload
        expect(settings.sunat_next_grr_series).to eq("T001")
        expect(settings.sunat_next_grr_number).to eq(43)
      end
    end

    context 'when guide is GRT' do
      let(:guide) { create(:dispatch_guide, :grt, :public_transport, enterprise: enterprise, created_by: user) }

      before do
        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_dispatch_guide_transportista).and_return(
          api_response.merge("series" => "V001")
        )
      end

      it 'calls transportista endpoint' do
        subject.call
        expect(subject).to be_valid
        expect(guide.reload.sunat_document_type).to eq("31")
      end

      it 'saves next document info for GRT' do
        subject.call
        settings.reload
        expect(settings.sunat_next_grt_series).to eq("T001")
        expect(settings.sunat_next_grt_number).to eq(43)
      end
    end

    context 'when guide is not draft' do
      before { guide.update_column(:status, "emitted") }

      it 'adds error and is invalid' do
        subject.call
        expect(subject).not_to be_valid
        expect(subject.errors_message).to include("La guia debe estar en borrador para emitir")
      end
    end

    context 'when guide already has SUNAT UUID with ACCEPTED status' do
      before do
        guide.update_columns(sunat_uuid: "existing-uuid", sunat_status: "ACCEPTED", status: "emitted")
      end

      it 'adds error' do
        subject.call
        expect(subject).not_to be_valid
        expect(subject.errors_message).to include("La guia debe estar en borrador para emitir")
      end
    end

    context 'when guide has a rejected document' do
      before do
        guide.update_columns(sunat_uuid: "rejected-uuid", sunat_status: "REJECTED")
        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:retry_dispatch_guide).with("rejected-uuid").and_return(api_response)
      end

      it 'retries using the existing document UUID' do
        subject.call
        expect(subject).to be_valid
        expect(guide.reload.sunat_status).to eq("ACCEPTED")
        expect(guide.status).to eq("emitted")
      end
    end

    context 'when guide has an errored document' do
      before do
        guide.update_columns(sunat_uuid: "errored-uuid", sunat_status: "ERROR")
        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:retry_dispatch_guide).with("errored-uuid").and_return(api_response)
      end

      it 'retries using the existing document UUID' do
        subject.call
        expect(subject).to be_valid
        expect(guide.reload.sunat_status).to eq("ACCEPTED")
      end
    end

    context 'when SUNAT rejects the document' do
      before do
        rejected_response = api_response.merge("status" => "REJECTED", "cdr_description" => "Documento rechazado")
        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_dispatch_guide_remitente).and_return(rejected_response)
      end

      it 'saves the UUID for future retry' do
        subject.call
        expect(subject).not_to be_valid
        guide.reload
        expect(guide.sunat_uuid).to be_present
        expect(guide.sunat_status).to eq("REJECTED")
        expect(guide.status).to eq("draft")
      end
    end

    context 'when microservice returns 502 with document data' do
      before do
        document_data = {
          "uuid" => "doc-from-502",
          "status" => "ERROR",
          "series" => "T001",
          "correlative" => 3
        }
        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_dispatch_guide_remitente).and_raise(
          Sunat::ApiClient::ServerErrorWithDocument.new("Error en SUNAT", document_data)
        )
      end

      it 'saves the document UUID for future retry' do
        subject.call
        expect(subject).not_to be_valid
        guide.reload
        expect(guide.sunat_uuid).to eq("doc-from-502")
        expect(guide.sunat_status).to eq("ERROR")
        expect(guide.status).to eq("draft")
      end
    end

    context 'when enterprise has no API key' do
      before { settings.update!(sunat_api_key: nil) }

      it 'adds error' do
        subject.call
        expect(subject).not_to be_valid
        expect(subject.errors_message).to include("La empresa no esta registrada en el servicio SUNAT")
      end
    end

    context 'when enterprise has no certificate' do
      before { settings.update!(sunat_certificate_uploaded: false) }

      it 'adds error' do
        subject.call
        expect(subject).not_to be_valid
        expect(subject.errors_message).to include("La empresa no tiene certificado digital cargado")
      end
    end

    context 'when guide has no items' do
      before { guide.items.destroy_all }

      it 'adds error' do
        subject.call
        expect(subject).not_to be_valid
        expect(subject.errors_message).to include("La guia debe tener al menos un item")
      end
    end

    context 'when API raises an error' do
      before do
        client = instance_double(Sunat::ApiClient)
        allow(Sunat::ApiClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_dispatch_guide_remitente).and_raise(Sunat::ApiClient::Error, "Connection refused")
      end

      it 'catches the error and is invalid' do
        subject.call
        expect(subject).not_to be_valid
        expect(subject.errors_message).to include("Connection refused")
      end

      it 'does not change guide status' do
        subject.call
        expect(guide.reload.status).to eq("draft")
      end
    end
  end
end
