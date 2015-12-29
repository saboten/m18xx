class Corporation
  include Mongoid::Document

  embedded_in :game_session

  field :initials, type: String
  field :money, type: Integer, default: 0
  field :income, type: Integer, default: 0

  validates :money, :numericality => { :only_integer => true }
  validates :initials, :presence => true
  scope :alphabetical, lambda {order(:initials => :asc)}

  CORPORATIONS = {}
  Dir.glob("#{Rails.root}/data/corporations/*.yml") do |yml|
    CORPORATIONS.merge!(YAML.load_file(yml))
  end

  def self.corporations(game = M18xx::Application.config.game)
    return CORPORATIONS[game]
  end

  def id_s
    id.to_s
  end

  def floated?
    return (_parent.shares.issued_by(id_s).sum(:quantity) >= 6)
  end

  def bank_share
    _parent.shares.belonging_to(id_s).first
  end

  #TODO Consider refactoring some of this
  def name
    return Corporation.corporations[initials]["print_initials"]
  end

  def long_name
    return Corporation.corporations[initials]["name"]
  end

  def print_initials
    return Corporation.corporations[initials]["print_initials"]
  end

  def css_color(type = "color-primary")
    color_set = Corporation.corporations[initials][type]
    return "rgb(#{color_set["r"]},#{color_set["g"]},#{color_set["b"]})"
  end

  def current_state
    return {"corporation_id" => id, "money" => money, "income" => income}
  end
end
