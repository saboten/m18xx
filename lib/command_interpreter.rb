class CommandInterpreter
  attr_reader :action, :value, :options
  VALID_ACTIONS = [:add, :sub, :buy, :sell, :run, :sell_company, :remove, :company_payout, :undo]
  VALID_OPTIONS = [:p, :c, :s, :b, :i, :q, :v, :w]
  REQUIRED_OPTIONS = {
    buy: [:p,:s,:v],
    sell: [:p,:s,:v],
    run: [:v],
    sell_company: [:v]
  }
  REQUIRES_VALUE = [:add, :sub, :run, :sell_company, :remove]

  def initialize(command_string)
    split_commands = command_string.split("-")
    command_action = split_commands.first.split(" ")
    @action = command_action[0].to_sym
    @value = command_action[1] if command_action.length > 1
    @options = Hash.new(false)

    split_commands.delete_at(0)
    split_commands.each do |c|
      option_value = c[1..-1].strip
      @options[c[0].to_sym] = option_value == "" ? true : option_value
    end

    validate_options
  end

  private

  def validate_options
    raise Exception.new("Invalid Action: #{@action}") unless VALID_ACTIONS.include?(@action)
    raise Exception.new("Action #{@action} requires a value") if @value.nil? and REQUIRES_VALUE.include?(@action)
    @options.each_pair do |k,v|
      raise Exception.new("Invalid Option: #{k.to_s}") unless VALID_OPTIONS.include?(k)
      if k == :q or k == :v
        if numeric?(v)
          @options[k] = v.to_i
        else
          raise Exception.new("Invalid Number: #{v.to_s}")
        end
      end
    end
    case @action
    when :add
      raise Exception.new("Add command must include either a player or a corporation option") if !@options.key?(:p) and !@options.key?(:c)
    when :sub
      raise Exception.new("Sub command must include either a player or a corporation option") if !@options.key?(:p) and !@options.key?(:c)
    when :buy
      REQUIRED_OPTIONS[:buy].each do |o|
        raise Exception.new("Buy command must include option: #{o}") unless @options.key?(o)
      end
    when :sell
      REQUIRED_OPTIONS[:sell].each do |o|
        raise Exception.new("Sell command must include option: #{o}") unless @options.key?(o)
      end
    when :run
      REQUIRED_OPTIONS[:run].each do |o|
        raise Exception.new("Run command must include option: #{o}") unless @options.key?(o)
      end
    when :sell_company
      raise Exception.new("Sell_company command must include either a player or a corporation option") if !@options.key?(:p) and !@options.key?(:c)
      REQUIRED_OPTIONS[:sell_company].each do |o|
        raise Exception.new("Sell_company command must include option: #{o}") unless @options.key?(o)
      end
    end
  end

  def numeric?(string)
    true if Float(string) rescue false
  end
end
