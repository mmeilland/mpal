class Occupant < ActiveRecord::Base

  enum civilite: [ 'mr', 'mme']
  belongs_to :projet
  has_many   :avis_impositions

  validates :nom, :prenom, :date_de_naissance, presence: true

  scope :sans_revenus, -> { where(revenus: nil) }

  def to_s
    "#{prenom} #{nom}"
  end
end
