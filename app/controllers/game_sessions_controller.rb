require 'command_interpreter'
class GameSessionsController < ApplicationController

  def index
    @games = GameSession.all
  end

  def new
    @game = GameSession.new
    @new_player = Player.new
  end

  def create
    #Create game and players
    @game = GameSession.new(params.require(:game_session).permit(:id, :bank, players_attributes: [:id, :name, :money]))
    index = 1
    @game.players.each do |p|
      p.index = index
      index += 1
    end
    unless @game.save
      render action: 'new'
      return
    end
    #Add companies present in every game
    Company.companies.each do |key, value|
      if value["core"] == true
        @game.companies.create(initials: key, owner_id: @game.players[params[:company_owner][key].to_i].id)
      end
    end
    #Add companies present in variations of game
    params[:company].each do |key, value|
      if value == "1"
        @game.companies.create(initials: key, owner_id: @game.players[params[:company_owner][key].to_i].id)
      end
    end
    #Add corporations present in every game
    Corporation.corporations.each do |key, value|
      if value["core"] == true
        @game.corporations.create(initials: key)
      end
    end
    #Add corporations present in variations of game
    params[:corporation].each do |key, value|
      if value == "1"
        @game.corporations.create(initials: key)
      end
    end
    #Initialize share quantities
    @game.corporations.each do |c|
      @game.shares.create(corporation_id: c.id_s, owner_id: c.id_s, quantity: 0)
      @game.players.each do |p|
        @game.shares.create(corporation_id: c.id_s, owner_id: p.id_s, quantity: 0)
      end
    end
    #Initialize previous state so that adding starting shares doesn't break
    @game.init_previous_state
    #TODO Move this into a more generic method for evaluating game-specific rules.
    @game.add_share("prr", @game.companies.with_identifier("ca").owner_id, 1)
    @game.add_share("bo", @game.companies.with_identifier("bo").owner_id, 2)

    redirect_to root_path
  end

  def show
    @game = GameSession.find(params[:id])
    @money_change = Hash.new({})
    @data = {command_url: command_game_session_path(id: @game.id), score_url: final_score_game_session_path(id: @game.id)}
    #TODO Add game-not-found code here
  end

  def destroy
    @game = GameSession.find(params[:id])
    @game.destroy
    flash[:notice] = "Successfully removed game session"
    redirect_to root_path
  end

  #Retun a flash[:notice] with the final scores of the game
  def final_score
    @game = GameSession.find(params[:id])
    @money_change = Hash.new({})
    share_values = Hash[params[:share_values].map{ |k, v| [k, v.to_i] }]
    scores = Array.new
    @game.players.each do |p|
      score = p.money
      @game.shares.belonging_to(p.id_s).each {|s| score += s.quantity * share_values[s.corporation_id]}
      scores.push({name: p.name, score: score})
    end
    scores.sort! {|x,y| y[:score] <=> x[:score]}
    #TODO Find a different way to display this
    results_string = "<b>Final Results</b><br />"
    scores.each {|s| results_string += "#{s[:name]}: #{s[:score]}<br />"}
    flash[:notice] = results_string
    render :show, layout: false
  end

  #Parse a text command and adjust the game accordingly
  def command
    @game = GameSession.find(params[:id])
    @money_change = Hash.new({})
    begin
      command = CommandInterpreter.new(params[:command])
      #Reset the game's last state unless the command requests that the game revert to that state
      @game.init_previous_state unless command.action == :undo
      case command.action
      when :add, :sub
        flash[:notice] = parse_add_subract(command)
      when :company_payout
        flash[:notice] = parse_company_payout(command)
      when :run
        flash[:notice] = parse_run(command)
      when :sell_company
        flash[:notice] = parse_sell_company(command)
      when :buy, :sell
        flash[:notice] = parse_buy_sell(command)
      when :remove
        flash[:notice] = parse_remove(command)
      when :undo
        @game.restore_previous_state
        flash[:notice] = "State restored"
      end
    rescue Exception => e
      flash[:error] = e.message
    end
    render :show, layout: false
  end

  private

  def parse_add_subract(command)
    value = command.value.to_i || 1
    options = command.options
    if command.action == :sub
      results_string = "Subtracted #{value}"
      value = -value
    else
      results_string = "Added #{value}"
    end
    if(options.key?(:p))
      target = @game.players.with_identifier(options[:p])
    else
      target = @game.corporations.with_identifier(options[:c])
    end
    if(options.key?(:s))
      @game.add_share(options[:s], target.id_s, value)
      results_string += " shares of #{@game.corporations.with_identifier(options[:s]).name}. Target: #{target.name}"
    else
      add_money(target, value)
      results_string += " dollars. Target: #{target.name}"
    end
    return results_string
  end

  def parse_company_payout(command)
    #Income is added to this hash before being added to players/corps so that @money_change stores an accurate value
    income = Hash.new(0)
    @game.companies.each do |c|
      unless c.removed
        income[c.owner_id] += Company.companies[c.initials]["revenue"]
      end
    end
    income.each_pair {|target_id,value| add_money(@game.player_or_corporation(target_id), value)}
    return "Private Companies paid income"
  end

  def parse_buy_sell(command)
    options = command.options
    player = @game.players.with_identifier(options[:p])
    quantity = options[:q] || 1
    if command.action == :sell
      results_string = "Sold #{quantity}"
      quantity = -quantity
    else
      results_string = "Bought #{quantity}"
    end
    @game.add_share(options[:s], player.id_s, quantity, options[:b])
    add_money(player, -(options[:v] * quantity))
    results_string += " share of #{@game.corporations.with_identifier(options[:s]).name} for #{options[:v]} apiece"
    results_string += " from the bank pool" if options[:b]
    results_string += "<br />Target: #{player.name}"
    return results_string
  end

  def parse_run(command)
    options = command.options
    corporation = @game.corporations.with_identifier(command.value)
    @game.previous_state["income"].push({"corporation_id" => corporation.id_s, "income" => corporation.income})
    corporation.income = options[:v]
    @game.save!
    results_string = "Ran trains belonging to #{corporation.name} valued at #{options[:v]}<br />"
    if(options[:w])
      add_money(corporation, options[:v])
      results_string += "Withheld money"
    else
      per_share_income = options[:v] / 10
      shares = @game.shares.issued_by(corporation.id_s)
      results_string += "Paid out:"
      shares.each do |s|
        if s.quantity > 0
          add_money(s.owner, per_share_income * s.quantity)
          results_string += "<br />#{s.owner.name}: #{per_share_income * s.quantity}"
        end
      end
    end
    return results_string
  end

  def parse_sell_company(command)
    company = @game.companies.with_identifier(command.value)
    options = command.options
    if(options.key?(:p))
      target = @game.players.with_identifier(options[:p])
    else
      target = @game.corporations.with_identifier(options[:c])
    end
    add_money(company.owner, options[:v])
    add_money(target, -options[:v])
    @game.previous_state["company_state"].push(company.current_state)
    company.owner_id = target.id_s
    @game.save!
    return "Sold #{company.name} to #{target.name} for $#{options[:v]}"
  end

  def parse_remove(command)
    company = @game.companies.with_identifier(command.value)
    @game.previous_state["company_state"].push(company.current_state)
    company.removed = true
    @game.save!
    return "#{company.name} removed from the game"
  end

  def add_money(target, amount)
    @game.add_money(target, amount)
    @money_change[target] = {change: amount}
  end
end
