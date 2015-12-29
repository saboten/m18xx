class Share
  include Mongoid::Document

  embedded_in :game_session

  field :corporation_id, type: String
  field :owner_id, type: String
  field :quantity, type: Integer

  def id_s
    id.to_s
  end

  def owner
    _parent.player_or_corporation(owner_id)
  end
end
