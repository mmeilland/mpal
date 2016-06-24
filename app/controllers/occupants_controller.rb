class OccupantsController < ApplicationController
  def new
    @projet = Projet.find(params[:projet_id])
    @occupant = @projet.occupants.build
  end

  def create
    @projet = Projet.find(params[:projet_id])
    @occupant = @projet.occupants.build(occupant_params)    
    if @occupant.save
      redirect_to @projet
    else
      render :new
    end
  end

  private
  def occupant_params
    params.require(:occupant).permit(:civilite, :prenom, :nom, :date_de_naissance, :lien_demandeur)
  end
end

