class Company
  include Mongoid::Document

  embedded_in :game_session

  field :initials, type: String
  field :owner_id, type: String
  field :removed, type: Boolean, default: false

  COMPANIES = {}
  Dir.glob("#{Rails.root}/data/companies/*.yml") do |yml|
    COMPANIES.merge!(YAML.load_file(yml))
  end

  def self.companies(game = M18xx::Application.config.game)
    return COMPANIES[game]
  end

  def id_s
    id.to_s
  end

  def name
    return Company.companies[initials]["name"]
  end

  def owner
    return game_session.player_or_corporation(owner_id)
  end

  def current_state
    return {"company_id" => id, "owner_id" => owner_id, "removed" => removed}
  end

  def owner_name
    if removed
      return "None"
    else
      return owner.name
    end
  end

end
