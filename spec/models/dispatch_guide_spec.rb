require 'rails_helper'

RSpec.describe DispatchGuide, type: :model do
  describe 'associations' do
    it { should belong_to(:enterprise) }
    it { should belong_to(:created_by).class_name("User") }
    it { should belong_to(:departure_ubigeo).class_name("Ubigeo").optional }
    it { should belong_to(:arrival_ubigeo).class_name("Ubigeo").optional }
    it { should belong_to(:vehicle).optional }
    it { should belong_to(:driver).class_name("User").optional }
    it { should belong_to(:carrier).optional }
    it { should have_many(:items).class_name("DispatchGuideItem").dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:guide_type).with_values(grr: "grr", grt: "grt").backed_by_column_of_type(:string) }
    it { should define_enum_for(:status).with_values(draft: "draft", emitted: "emitted", cancelled: "cancelled").backed_by_column_of_type(:string) }
  end

  describe 'validations' do
    it 'is valid with valid GRR attributes' do
      guide = build(:dispatch_guide)
      expect(guide).to be_valid
    end

    it 'is valid with valid GRT attributes' do
      guide = build(:dispatch_guide, :grt)
      expect(guide).to be_valid
    end

    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:issue_date) }
    it { should validate_presence_of(:transfer_date) }
    it { should validate_presence_of(:departure_address) }
    it { should validate_presence_of(:arrival_address) }

    context 'GRR (remitente)' do
      subject { build(:dispatch_guide, guide_type: :grr) }

      it { should validate_presence_of(:recipient_name) }
      it { should validate_presence_of(:recipient_doc_number) }
      it { should validate_presence_of(:recipient_doc_type) }
    end

    context 'GRT (transportista)' do
      subject { build(:dispatch_guide, :grt) }

      it { should validate_presence_of(:shipper_name) }
      it { should validate_presence_of(:shipper_doc_number) }
      it { should validate_presence_of(:shipper_doc_type) }
    end

    context 'private transport' do
      subject { build(:dispatch_guide, transport_modality: :private_transport) }

      it { should validate_presence_of(:vehicle) }
      it { should validate_presence_of(:driver) }
    end

    context 'public transport' do
      subject { build(:dispatch_guide, :public_transport) }

      it { should validate_presence_of(:carrier) }
    end

    it 'validates code uniqueness scoped to enterprise' do
      enterprise = create(:enterprise)
      user = create(:user)
      create(:dispatch_guide, enterprise: enterprise, created_by: user, code: "GR-0001-2026")
      duplicate = build(:dispatch_guide, enterprise: enterprise, created_by: user, code: "GR-0001-2026")
      expect(duplicate).not_to be_valid
    end

    it 'validates gross_weight is positive when present' do
      guide = build(:dispatch_guide, gross_weight: -1)
      expect(guide).not_to be_valid
    end

    it 'allows nil gross_weight' do
      guide = build(:dispatch_guide, gross_weight: nil)
      expect(guide).to be_valid
    end
  end

  describe '.generate_next_code' do
    let(:enterprise) { create(:enterprise) }

    it 'generates first code for enterprise' do
      code = DispatchGuide.generate_next_code(enterprise)
      expect(code).to eq("GR-0001-#{Date.current.year}")
    end

    it 'increments based on last code' do
      user = create(:user)
      create(:dispatch_guide, enterprise: enterprise, created_by: user, code: "GR-0005-#{Date.current.year}")
      code = DispatchGuide.generate_next_code(enterprise)
      expect(code).to eq("GR-0006-#{Date.current.year}")
    end
  end

  describe 'status helpers' do
    let(:draft_guide) { build(:dispatch_guide, status: :draft) }
    let(:emitted_guide) { build(:dispatch_guide, :emitted) }

    it '#can_edit? returns true for draft' do
      expect(draft_guide.can_edit?).to be true
    end

    it '#can_edit? returns false for emitted' do
      expect(emitted_guide.can_edit?).to be false
    end

    it '#can_cancel? returns true for draft' do
      expect(draft_guide.can_cancel?).to be true
    end

    it '#can_cancel? returns false for emitted' do
      expect(emitted_guide.can_cancel?).to be false
    end

    it '#can_retry_document? returns true for ERROR status' do
      guide = build(:dispatch_guide, sunat_uuid: "abc", sunat_status: "ERROR")
      expect(guide.can_retry_document?).to be true
    end

    it '#can_retry_document? returns false for ACCEPTED status' do
      guide = build(:dispatch_guide, sunat_uuid: "abc", sunat_status: "ACCEPTED")
      expect(guide.can_retry_document?).to be false
    end
  end

  describe 'SUNAT display helpers' do
    it '#sunat_formatted_number formats with zero-padded number' do
      guide = build(:dispatch_guide, sunat_series: "T001", sunat_number: 42)
      expect(guide.sunat_formatted_number).to eq("T001-00000042")
    end

    it '#sunat_formatted_number returns nil when series blank' do
      guide = build(:dispatch_guide, sunat_series: nil)
      expect(guide.sunat_formatted_number).to be_nil
    end

    it '#sunat_document_type_label returns correct labels' do
      expect(build(:dispatch_guide, sunat_document_type: "09").sunat_document_type_label).to eq("Guia Remitente")
      expect(build(:dispatch_guide, sunat_document_type: "31").sunat_document_type_label).to eq("Guia Transportista")
    end

    it '#status_label returns Spanish labels' do
      expect(build(:dispatch_guide, status: :draft).status_label).to eq("Borrador")
      expect(build(:dispatch_guide, :emitted).status_label).to eq("Emitida")
    end

    it '#guide_type_label returns correct labels' do
      expect(build(:dispatch_guide, guide_type: :grr).guide_type_label).to eq("Remitente")
      expect(build(:dispatch_guide, :grt).guide_type_label).to eq("Transportista")
    end
  end

  describe '#cancel!' do
    it 'cancels a draft guide' do
      guide = create(:dispatch_guide)
      expect(guide.cancel!).to be_truthy
      expect(guide.reload.status).to eq("cancelled")
    end

    it 'returns false for emitted guide' do
      guide = create(:dispatch_guide, :emitted)
      expect(guide.cancel!).to be false
    end
  end
end
