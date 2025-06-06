# frozen_string_literal: true

require "spec_helper"

module Api
  RSpec.describe V0::LogosController, type: :controller do
    include AuthenticationHelper
    include FileHelper

    let(:admin_user) { create(:admin_user) }
    let(:enterprise_owner) { create(:user) }
    let(:enterprise) { create(:enterprise, owner: enterprise_owner ) }
    let(:enterprise_manager) { create(:user, enterprise_limit: 10, enterprises: [enterprise]) }
    let(:other_enterprise_owner) { create(:user) }
    let(:other_enterprise) { create(:enterprise, owner: other_enterprise_owner ) }
    let(:other_enterprise_manager) {
      create(:user, enterprise_limit: 10, enterprises: [other_enterprise])
    }

    describe "removing logo" do
      let(:image) { black_logo_file }

      let(:enterprise) { create(:enterprise, owner: enterprise_owner, logo: image) }

      before do
        allow(controller).to receive(:spree_current_user) { current_user }
      end

      context "as manager" do
        let(:current_user) { enterprise_manager }

        it "removes logo" do
          spree_delete :destroy, enterprise_id: enterprise

          expect(response).to have_http_status :ok
          expect(json_response["id"]).to eq enterprise.id
          enterprise.reload
          expect(enterprise.logo).not_to be_attached
        end

        context "when logo does not exist" do
          let(:enterprise) { create(:enterprise, owner: enterprise_owner, logo: nil) }

          it "responds with error" do
            spree_delete :destroy, enterprise_id: enterprise

            expect(response).to have_http_status(:conflict)
            expect(json_response['error']).to eq 'Logo does not exist'
          end
        end
      end

      context "as owner" do
        let(:current_user) { enterprise_owner }

        it "allows removal of logo" do
          spree_delete :destroy, enterprise_id: enterprise
          expect(response).to have_http_status :ok
        end
      end

      context "as super admin" do
        let(:current_user) { admin_user }

        it "allows removal of logo" do
          spree_delete :destroy, enterprise_id: enterprise
          expect(response).to have_http_status :ok
        end
      end

      context "as manager of other enterprise" do
        let(:current_user) { other_enterprise_manager }

        it "does not allow removal of logo" do
          spree_delete :destroy, enterprise_id: enterprise
          expect(response).to have_http_status(:unauthorized)
          enterprise.reload
          expect(enterprise.logo).to be_attached
        end
      end

      context "as owner of other enterprise" do
        let(:current_user) { other_enterprise_owner }

        it "does not allow removal of logo" do
          spree_delete :destroy, enterprise_id: enterprise
          expect(response).to have_http_status(:unauthorized)
          enterprise.reload
          expect(enterprise.logo).to be_attached
        end
      end
    end
  end
end
