require "rails_helper"
require "support/mpal_helper"
require "support/opal_helper"

describe PaymentsController do

  describe "en tant qu'opérateur" do
    let(:projet)  { create :projet, :transmis_pour_instruction, :with_payment_registry }
    let(:payment) { create :payment, beneficiaire: "Emile Lévesque", payment_registry: projet.payment_registry }

    before(:each) { authenticate_as_agent projet.agent_operateur }

    describe "#new" do
      before do
        get :new, params: { dossier_id: projet.id }
      end
      it { is_expected.to render_template :new }
    end

    describe "#create" do
      context "avec des paramètres requis non remplis" do
        it "ne crée pas de demande de paiement" do
          post :create, params: {
            dossier_id: projet.id,
            payment: {
              procuration: "false",
            }
          }
          expect(Payment.count).to eq 0
          expect(response).to render_template :new
        end
      end

      context "avec tous les paramètres requis" do
        it "crée une demande de paiement" do
          post :create, params: {
            dossier_id: projet.id,
            payment: {
              type_paiement: "avance",
              beneficiaire: "SOLIHA",
              procuration: "true",
            }
          }
          projet.reload
          payment = projet.payment_registry.payments.first
          expect(Payment.count).to     eq 1
          expect(payment.type_paiement).to eq "avance"
          expect(payment.beneficiaire).to  eq "SOLIHA"
          expect(payment.procuration).to   eq true
          expect(payment.projet_id).to     eq projet.id #TODO Delete with PaymentRegistry
          expect(response).to redirect_to dossier_payment_registry_path(projet)
        end
      end

      context "sans procuration" do
        it "crée une demande de paiement pour le demandeur du projet" do
          post :create, params: {
            dossier_id: projet.id,
            payment: {
              type_paiement: "avance",
              beneficiaire: "SOLIHA",
              procuration: "false",
            }
          }
          projet.reload
          payment = projet.payment_registry.payments.first
          expect(Payment.count).to     eq 1
          expect(payment.type_paiement).to eq "avance"
          expect(payment.beneficiaire).to  eq projet.demandeur.fullname
          expect(payment.procuration).to   eq false
          expect(payment.projet_id).to     eq projet.id #TODO Delete with PaymentRegistry
          expect(response).to redirect_to dossier_payment_registry_path(projet)
        end
      end
    end

    describe "#edit" do
      before do
        get :edit, params: { dossier_id: projet.id, payment_id: payment.id }
      end
      it { is_expected.to render_template :edit }
    end

    describe "#update" do
      context "avec des paramètres requis non remplis" do
        it "ne modifie pas la demande de paiement" do
          put :update, params: {
            dossier_id: projet.id,
            payment_id: payment.id,
            payment: {
              type_paiement: "solde",
              procuration: "true",
            }
          }
          payment.reload
          expect(Payment.count).to     eq 1
          expect(payment.type_paiement).to eq "avance"
          expect(payment.beneficiaire).to  eq "Emile Lévesque"
          expect(payment.procuration).to   eq false
          expect(response).to render_template :edit
        end
      end

      context "avec tous les paramètres requis" do
        it "modifie la demande de paiement" do
          put :update, params: {
            dossier_id: projet.id,
            payment_id: payment.id,
            payment: {
              type_paiement: "solde",
              beneficiaire: "SOLIHA",
              procuration: "true",
            }
          }
          payment.reload
          expect(Payment.count).to     eq 1
          expect(payment.type_paiement).to eq "solde"
          expect(payment.beneficiaire).to  eq "SOLIHA"
          expect(payment.procuration).to   eq true
          expect(payment.projet_id).to     eq projet.id #TODO Delete with PaymentRegistry
          expect(response).to redirect_to dossier_payment_registry_path(projet)
        end
      end

      context "sans procuration" do
        it "modifie la demande de paiement pour le demandeur du projet" do
          put :update, params: {
            dossier_id: projet.id,
            payment_id: payment.id,
            payment: {
              type_paiement: "solde",
              beneficiaire: "SOLIHA",
              procuration: "false",
            }
          }
          payment.reload
          expect(Payment.count).to     eq 1
          expect(payment.type_paiement).to eq "solde"
          expect(payment.beneficiaire).to  eq projet.demandeur.fullname
          expect(payment.procuration).to   eq false
          expect(payment.projet_id).to     eq projet.id #TODO Delete with PaymentRegistry
          expect(response).to redirect_to dossier_payment_registry_path(projet)
        end
      end
    end

    describe "#destroy" do
      it "supprime la demande de paiement" do
        delete :destroy, params: { dossier_id: projet.id, payment_id: payment.id }
        expect(Payment.count).to eq 0
        expect(response).to redirect_to dossier_payment_registry_path(projet)
      end

      context "avec une demande de paiement vue par le demandeur" do
        before { payment.update! statut: :propose, action: :a_modifier }

        it "envoie un mail au demandeur" do
          expect(PaymentMailer).to receive(:destruction).once.and_call_original.with(payment)
          delete :destroy, params: { dossier_id: projet.id, payment_id: payment.id }
        end
      end

      context "si une erreur survient lors de la suppression" do
        it "affiche un message d’erreur" do
          delete :destroy, params: { dossier_id: projet.id, payment_id: (payment.id + 1) }
          expect(response).to redirect_to "/404"
        end
      end
    end

    describe "#ask_for_validation" do
      let(:projet) { create :projet, :en_cours_d_instruction, :with_payment_registry}

      it "passe la demande en proposé au demandeur pour validation" do
        expect(PaymentMailer).to receive(:demande_validation).once.and_call_original.with(payment)
        put :ask_for_validation, params: { dossier_id: projet.id, payment_id: payment.id }
        payment.reload
        expect(payment.action).to eq "a_valider"
        expect(payment.statut).to eq "propose"
        expect(response).to redirect_to dossier_payment_registry_path(projet)
      end
    end
  end

  describe "en tant que demandeur" do
    let(:projet)      { create :projet, :en_cours_d_instruction, :with_payment_registry }
    let(:payment)     { create :payment, statut: "propose", action: "a_valider", beneficiaire: "Emile Lévesque", payment_registry: projet.payment_registry }
    let(:submit_time) { Time.now }

    before(:each) { authenticate_as_user projet.demandeur_user }

    describe "#ask_for_modification" do
      it "passe la demande a l'opérateur pour modification" do
        expect(PaymentMailer).to receive(:demande_modification).once.and_call_original.with(payment, true)
        put :ask_for_modification, params: { projet_id: projet.id, payment_id: payment.id }
        payment.reload
        expect(payment.action).to eq "a_modifier"
        expect(payment.statut).to eq "propose"
        expect(response).to redirect_to projet_payment_registry_path(projet)
      end
    end

    describe "#ask_for_instruction" do
      it "passe la demande a l'instructeur pour instruction" do
        expect(PaymentMailer).to receive(:depot).once.and_call_original.with(payment, projet.operateur)
        expect(PaymentMailer).to receive(:depot).once.and_call_original.with(payment, projet.invited_instructeur)
        put :ask_for_instruction, params: { projet_id: projet.id, payment_id: payment.id }
        payment.reload
        expect(payment.action).to eq "a_instruire"
        expect(payment.statut).to eq "demande"
        expect(payment.submitted_at).to eq submit_time
        expect(response).to redirect_to projet_payment_registry_path(projet)
      end
    end
  end

  describe "en tant que instructeur" do
    let(:projet)            { create :projet, :en_cours_d_instruction, :with_payment_registry }
    let(:agent_instructeur) { projet.agent_instructeur }
    let(:submit_time)       { DateTime.new(1980, 01, 01) }
    let(:payment)           { create :payment, :demande, beneficiaire: "Emile Lévesque", payment_registry: projet.payment_registry, submitted_at: submit_time }

    describe "#send_in_opal" do
      before do
        authenticate_as_agent agent_instructeur
        put :send_in_opal, params: { dossier_id: projet.id, payment_id: payment.id }
        payment.reload
      end

      it "transmet la demande de paiement dans Opal et met à jour le statut" do
        expect(payment.statut).to eq "en_cours_d_instruction"
        expect(response).to redirect_to dossier_payment_registry_path(projet)
      end
    end
  end
end
