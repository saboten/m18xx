class Player
  include Mongoid::Document

  embedded_in :game_session

  field :name, type: String
  field :money, type: Integer
  field :index, type: Integer

  validates :money, :numericality => { :only_integer => true }
  validates :name, :presence => true
  validates :index, :numericality => { :only_integer => true, :greater_than_or_equal_to => 1, :less_than_or_equal_to => 6 }

  def id_s
    id.to_s
  end

  def css_color
    case index
    when 1
      return "#222"
    when 2
      return "#226"
    when 3
      return "#622"
    when 4
      return "#262"
    when 5
      return "#662"
    when 6
      return "#626"
    else
      return "#FFF"
    end
  end
end
