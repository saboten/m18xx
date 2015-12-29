class GameSession
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :players do
    def with_identifier(identifier)
      begin
        return find(identifier)
      rescue
        player = where(index: identifier).first
        if player.nil?
          player = where(name: identifier).first
        end
        raise "No Player with that identifier exists: #{identifier}" if player.nil?
        return player
      end
    end
  end
  accepts_nested_attributes_for :players, :reject_if => lambda { |p| p[:name].blank? }, :allow_destroy => true
  validate :player_number

  embeds_many :corporations do
    def with_identifier(identifier)
      begin
        return find(identifier)
      rescue
        return where(initials: identifier).first
      end
    end
  end
  embeds_many :companies do
    def with_identifier(identifier)
      begin
        return find(identifier)
      rescue
        return where(initials: identifier).first
      end
    end
  end
  embeds_many :shares do
    def belonging_to(owner_id)
      return where(owner_id: owner_id)
    end
    def issued_by(corporation_id)
      return where(corporation_id: corporation_id)
    end
  end

  field :bank, type: Integer
  field :priority_deal, type: Integer
  field :previous_state, type: Hash

  def bank_remaining
    active_money = 0
    corporations.each {|c| active_money += c.money}
    players.each {|p| active_money += p.money}
    return bank - active_money
  end

  def player_or_corporation(target_id)
    begin
      return players.find(target_id)
    rescue
      return corporations.find(target_id)
    end
  end

  def add_share(corp_identifier, player_id, delta, add_from_bank_pool = false, sell_into_initial_offering = false)
    player = players.with_identifier(player_id.to_s)
    corporation = corporations.with_identifier(corp_identifier)
    total_shares_in_play = shares.issued_by(corporation.id_s).sum(:quantity)
    target_share = shares.find_by(owner_id: player.id_s, corporation_id: corporation.id_s)
    bank_share = corporation.bank_share
    if target_share.quantity + delta < 0
      raise "You may not sell more shares than you own: Player shares: #{target_share.quantity}, Shares sold: #{delta.abs}"
    end
    if total_shares_in_play + delta > 10 and !add_from_bank_pool
      if bank_share.quantity > 0
        raise "Shares must be purchased from the bank pool: limit(#{bank_share.quantity})"
      else
        raise "There are not enough available shares in the game to process this transaction."
      end
    elsif bank_share == 0 and add_from_bank_pool == true
      raise "You can't buy shares from the bank because the bank is empty"
    else
      if(add_from_bank_pool or (delta < 0 and !sell_into_initial_offering))
        previous_state["share_quantity"].push({"share_id" => bank_share.id_s, "quantity" => bank_share.quantity})
        bank_share.quantity -= delta
      end
      previous_state["share_quantity"].push({"share_id" => target_share.id_s, "quantity" => target_share.quantity})
      target_share.quantity += delta
      player.index == players.length ? priority_deal = 1 : priority_deal = player.index + 1
      save!
    end
  end

  def add_money(target, amount)
    previous_state["money"].push({"target_id" => target.id_s, "money" => target.money})
    target.money += amount
    save!
  end

  def init_previous_state
    update({previous_state: {
      "money" => Array.new,
      "income" => Array.new,
      "share_quantity" => Array.new,
      "company_state" => Array.new
    }})
  end

  def restore_previous_state
    previous_state["money"].each {|s| player_or_corporation(s["target_id"]).update(money: s["money"])}
    previous_state["income"].each {|s| corporations.find(s["corporation_id"]).update(income: s["income"])}
    previous_state["share_quantity"].each {|s| shares.find(s["share_id"]).update(quantity: s["quantity"])}
    previous_state["company_state"].each {|s| companies.find(s["company_id"]).update(owner_id: s["owner_id"], removed: s["removed"])}
  end

  private

  def player_number
    if players.reject(&:marked_for_destruction?).length < 3
      errors.add(:base, "Game must have at least three players")
    end
  end

end
