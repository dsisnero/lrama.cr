module Lrama
  class TableBuilder
    ErrorActionNumber = Int32::MIN + 1
    BaseMin           = Int32::MIN

    getter yydefact : Array(Int32)
    getter yydefgoto : Array(Int32)
    getter yypact : Array(Int32)
    getter yypgoto : Array(Int32)
    getter yytable : Array(Int32)
    getter yycheck : Array(Int32)
    getter yylast : Int32
    getter yypact_ninf : Int32
    getter yytable_ninf : Int32

    def initialize(@states : States, @grammar : Grammar)
      @yydefact = [] of Int32
      @yydefgoto = [] of Int32
      @yypact = [] of Int32
      @yypgoto = [] of Int32
      @yytable = [] of Int32
      @yycheck = [] of Int32
      @yylast = 0
      @yypact_ninf = 0
      @yytable_ninf = 0
      @actions = [] of ActionVector
      @sorted_actions = [] of ActionVector
      compute_tables
    end

    def yyr1 : Array(Int32)
      values = [0]
      @states.rules.each do |rule|
        values << (rule.lhs.try(&.number) || 0)
      end
      values
    end

    def yyr2 : Array(Int32)
      values = [0]
      @states.rules.each do |rule|
        values << rule.rhs.size
      end
      values
    end

    def yyfinal : Int32
      final_state =
        @states.states.find do |state|
          state.items.any? { |item| item.rule.lhs.try(&.accept_symbol?) && item.end_of_rule? }
        end
      final_state ? final_state.id : 0
    end

    def yyntokens : Int32
      @states.terms.size
    end

    def error_symbol : Int32
      @grammar.error_symbol!.number || 0
    end

    def eof_symbol : Int32
      @grammar.eof_symbol!.number || 0
    end

    def to_tables : Generator::Crystal::Tables
      Generator::Crystal::Tables.new(
        yypact: @yypact,
        yypgoto: @yypgoto,
        yydefact: @yydefact,
        yydefgoto: @yydefgoto,
        yytable: @yytable,
        yycheck: @yycheck,
        yyr1: yyr1,
        yyr2: yyr2,
        yylast: @yylast,
        yypact_ninf: @yypact_ninf,
        yytable_ninf: @yytable_ninf,
        yyfinal: yyfinal,
        error_symbol: error_symbol,
        eof_symbol: eof_symbol,
        yyntokens: yyntokens
      )
    end

    private struct ActionVector
      getter state_id : Int32
      getter pairs : Array(Tuple(Int32, Int32))
      getter count : Int32
      getter width : Int32

      def initialize(@state_id : Int32, @pairs : Array(Tuple(Int32, Int32)), @count : Int32, @width : Int32)
      end
    end

    private def vectors_count
      @states.states.size + @states.nterms.size
    end

    private def rule_id_to_action_number(rule_id : Int32)
      (rule_id + 1) * -1
    end

    private def nterm_number_to_sequence_number(nterm_number : Int32)
      nterm_number - @states.terms.size
    end

    private def nterm_number_to_vector_number(nterm_number : Int32)
      @states.states.size + (nterm_number - @states.terms.size)
    end

    private def compute_tables
      compute_yydefact
      compute_yydefgoto
      sort_actions
      compute_packed_table
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def compute_yydefact
      @yydefact = Array.new(@states.states.size, 0)

      @states.states.each do |state|
        actions = Array.new(@states.terms.size, 0)

        if state.reduces.map(&.selected_look_ahead).any? { |lookahead| !lookahead.empty? }
          state.reduces.reverse_each do |reduce|
            reduce.look_ahead.try do |look_ahead|
              look_ahead.each do |term|
                number = term.number || 0
                actions[number] = rule_id_to_action_number(reduce.rule.id || 0)
              end
            end
          end
        end

        state.selected_term_transitions.each do |shift|
          number = shift.next_sym.number || 0
          actions[number] = shift.to_state.id
        end

        state.resolved_conflicts.select { |conflict| conflict.which == :error }.each do |conflict|
          number = conflict.symbol.number || 0
          actions[number] = ErrorActionNumber
        end

        if default_rule = state.default_reduction_rule
          default_action = rule_id_to_action_number(default_rule.id || 0)
          actions.map! { |action| action == default_action ? 0 : action }
        else
          actions.map! { |action| action == ErrorActionNumber ? 0 : action }
        end

        entries = actions.each_with_index
          .map { |action, index| {index, action} }
          .reject { |pair| pair[1] == 0 }
          .to_a

        if !entries.empty?
          @actions << ActionVector.new(
            state.id,
            entries,
            entries.size,
            entries.last[0] - entries.first[0] + 1
          )
        end

        @yydefact[state.id] = default_rule ? (default_rule.id || 0) + 1 : 0
      end
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def compute_yydefgoto
      @yydefgoto = Array.new(@states.nterms.size, 0)
      nterm_to_to_states = {} of Grammar::Symbol => Array(Tuple(State, State))

      @states.states.each do |state|
        state.nterm_transitions.each do |goto|
          key = goto.next_sym
          nterm_to_to_states[key] ||= [] of Tuple(State, State)
          nterm_to_to_states[key] << {state, goto.to_state}
        end
      end

      @states.nterms.each do |nterm|
        if states = nterm_to_to_states[nterm]?
          default_state = states.map(&.[1]).group_by { |value| value }.max_by { |_, values| values.size }.first
          default_goto = default_state.id
          not_default_gotos = [] of Tuple(Int32, Int32)
          states.each do |from_state, to_state|
            next if to_state.id == default_goto
            not_default_gotos << {from_state.id, to_state.id}
          end
        else
          default_goto = 0
          not_default_gotos = [] of Tuple(Int32, Int32)
        end

        sequence_number = nterm_number_to_sequence_number(nterm.number || 0)
        @yydefgoto[sequence_number] = default_goto

        if !not_default_gotos.empty?
          vector_number = nterm_number_to_vector_number(nterm.number || 0)
          @actions << ActionVector.new(
            vector_number,
            not_default_gotos,
            not_default_gotos.size,
            not_default_gotos.last[0] - not_default_gotos.first[0] + 1
          )
        end
      end
    end

    private def sort_actions
      @sorted_actions = [] of ActionVector

      @actions.each do |action|
        if @sorted_actions.empty?
          @sorted_actions << action
          next
        end

        j = @sorted_actions.size - 1
        width = action.width
        count = action.count

        while j >= 0
          if @sorted_actions[j].width < width
            j -= 1
            next
          end
          if @sorted_actions[j].width == width && @sorted_actions[j].count < count
            j -= 1
            next
          end
          break
        end

        @sorted_actions.insert(j + 1, action)
      end
    end

    private def compute_packed_table
      base = Array.new(vectors_count, BaseMin)
      table = [] of Int32?
      check = [] of Int32?
      pushed = {} of Array(Tuple(Int32, Int32)) => Int32
      used_res = {} of Int32 => Bool
      lowzero = 0
      high = 0

      @sorted_actions.each do |action|
        pairs = action.pairs
        if res = pushed[pairs]?
          base[action.state_id] = res
          next
        end

        res = lowzero - pairs.first[0]

        loop do
          advanced = false

          while used_res[res]?
            res += 1
            advanced = true
          end

          pairs.each do |from, _to|
            while table[res + from]?
              res += 1
              advanced = true
            end
          end

          break unless advanced
        end

        loc = 0
        pairs.each do |from, to_state|
          loc = res + from
          ensure_size(table, loc + 1)
          ensure_size(check, loc + 1)
          table[loc] = to_state
          check[loc] = from
        end

        while table[lowzero]?
          lowzero += 1
        end

        high = loc if high < loc
        base[action.state_id] = res
        pushed[pairs] = res
        used_res[res] = true
      end

      @yylast = high

      @yypact_ninf = (base.reject { |i| i == BaseMin } + [0]).min - 1
      mapped_base = base.map { |value| value == BaseMin ? @yypact_ninf : value }
      state_count = @states.states.size
      @yypact = mapped_base[0...state_count]
      @yypgoto = mapped_base[state_count..-1] || [] of Int32

      @yytable_ninf = (table.compact.reject { |i| i == ErrorActionNumber } + [0]).min - 1
      @yytable = table.map do |value|
        case value
        when nil
          0
        when ErrorActionNumber
          @yytable_ninf
        else
          value
        end
      end
      @yycheck = check.map { |value| value.nil? ? -1 : value }
    end

    private def ensure_size(array : Array(Int32?), size : Int32)
      return if array.size >= size
      while array.size < size
        array << nil
      end
    end
  end
end
