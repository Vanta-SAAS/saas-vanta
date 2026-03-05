require "rails_helper"

RSpec.describe Users::RegisterWithEnterprise do
  describe "#call" do
    let!(:super_admin_role) { Role.find_or_create_by!(slug: "super_admin") { |r| r.name = "Super Administrador" } }

    let(:valid_params) do
      {
        user: {
          first_name: "Juan",
          first_last_name: "Perez",
          email_address: "juan@test.com"
        },
        enterprise: {
          comercial_name: "Mi Empresa Test"
        }
      }
    end

    context "with valid params" do
      it "creates a user, enterprise, and links them" do
        result = described_class.new(valid_params).call

        expect(result).to be_valid
        expect(result.user).to be_persisted
        expect(result.user).to be_pending
        expect(result.user).to be_standard
        expect(result.enterprise).to be_persisted
        expect(result.enterprise).to be_active
        expect(result.user.enterprises).to include(result.enterprise)
      end

      it "creates enterprise settings" do
        result = described_class.new(valid_params).call

        expect(result.enterprise.settings).to be_present
      end

      it "assigns super_admin role to the user" do
        result = described_class.new(valid_params).call

        expect(result.user.has_role?(result.enterprise, :super_admin)).to be true
      end

      it "generates an invitation token for email confirmation" do
        result = described_class.new(valid_params).call

        expect(result.user.invitation_token).to be_present
        expect(result.user.invitation_sent_at).to be_present
      end

      it "enqueues a confirmation email" do
        result = described_class.new(valid_params).call

        expect(result.user.invitation_token).to be_present
      end
    end

    context "with invalid user params" do
      it "returns errors when email is missing" do
        params = valid_params.deep_dup
        params[:user][:email_address] = ""

        result = described_class.new(params).call

        expect(result).not_to be_valid
        expect(result.errors).to be_present
      end
    end

    context "with invalid enterprise params" do
      it "returns errors when comercial_name is missing" do
        params = valid_params.deep_dup
        params[:enterprise][:comercial_name] = ""

        result = described_class.new(params).call

        expect(result).not_to be_valid
        expect(result.errors).to be_present
      end
    end

    context "with duplicate email" do
      it "returns errors" do
        create(:user, email_address: "juan@test.com")

        result = described_class.new(valid_params).call

        expect(result).not_to be_valid
      end
    end

    it "rolls back everything on failure" do
      params = valid_params.deep_dup
      params[:enterprise][:comercial_name] = ""

      expect { described_class.new(params).call }.not_to change { User.count }
      expect { described_class.new(params).call }.not_to change { Enterprise.count }
    end
  end
end
