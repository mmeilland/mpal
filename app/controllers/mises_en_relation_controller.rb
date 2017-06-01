class MisesEnRelationController < ApplicationController
  layout 'inscription'

  before_action :projet_or_dossier
  before_action :assert_projet_courant
  before_action :authentifie

  def show
    @demande = @projet_courant.demande
    fetch_pris_and_instructeur
    if @pris_departement.blank?
      Rails.logger.error "Il n’y a pas de PRIS disponible pour le département #{@projet_courant.departement} (projet_id: #{@projet_courant.id})"
      return redirect_to projet_demandeur_departement_non_eligible_path(@projet_courant)
    end
    @page_heading = 'Inscription'
    @action_label = action_label
  end

  def update
    begin
      @projet_courant.update_attribute(:disponibilite, params[:projet][:disponibilite])
      fetch_pris_and_instructeur
      unless @projet_courant.intervenants.include? @pris_departement
        @projet_courant.invite_pris! @pris_departement
        flash[:notice_titre] = t('invitations.messages.succes_titre')
        flash[:notice] = t('invitations.messages.succes', intervenant: @pris_departement.raison_sociale)
      end
      @projet_courant.invite_instructeur! @instructeur
      redirect_to projet_path(@projet_courant)
    rescue => e
      logger.error e.message
      redirect_to projet_mise_en_relation_path(@projet_courant), alert: t('demarrage_projet.mise_en_relation.error')
    end
  end

private
  def fetch_pris_and_instructeur
    if ENV['ROD_ENABLED'] == 'true'
      rod_response = Rod.new(RodClient).query_for(@projet_courant)
      @pris_departement = rod_response.pris
      @instructeur      = rod_response.instructeur
    else
      @pris_departement = @projet_courant.intervenants_disponibles(role: :pris).first
      @instructeur      = @projet_courant.intervenants_disponibles(role: :instructeur).first
    end
  end

  def action_label
    if needs_mise_en_relation?
      t('demarrage_projet.action')
    else
      t('projets.edition.action')
    end
  end

  def needs_mise_en_relation?
    @projet_courant.contacted_operateur.blank? && @projet_courant.invited_pris.blank?
  end
end
