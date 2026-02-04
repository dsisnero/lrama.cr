require "./tracer/duration"

module Lrama
  class Tracer
    def initialize(@io : IO? = nil, @options : Hash(Symbol, Bool) = {} of Symbol => Bool)
      @time_enabled = @options[:time]? ? true : false
      @automaton = @options[:automaton]? ? true : false
      @closure = @options[:closure]? ? true : false
      @rules = @options[:rules]? ? true : false
      @only_explicit_rules = @options[:only_explicit_rules]? ? true : false
      @actions = @options[:actions]? ? true : false
    end

    def trace(grammar : Grammar)
      trace_only_explicit_rules(grammar)
      trace_rules(grammar)
      trace_actions(grammar)
    end

    def trace_closure(state : State)
      return unless @closure || @automaton
      return unless io = @io

      io << "Closure: input" << "\n"
      state.kernels.each do |item|
        io << "  #{item.display_rest}" << "\n"
      end
      io << "\n\n"
      io << "Closure: output" << "\n"
      state.items.each do |item|
        io << "  #{item.display_rest}" << "\n"
      end
      io << "\n\n"
    end

    def trace_state(state : State)
      return unless @automaton || @closure
      return unless io = @io

      previous = previous_symbol_for_trace(state)
      return unless previous

      io << "Processing state #{state.id} (reached by #{previous.display_name})" << "\n"
    end

    def trace_state_list_append(state_count : Int32, state : State)
      return unless @automaton || @closure
      return unless io = @io

      previous = previous_symbol_for_trace(state)
      return unless previous

      number = previous.number || 0
      io << sprintf("state_list_append (state = %d, symbol = %d (%s))",
        state_count, number, previous.display_name) << "\n"
    end

    def enable_duration
      Duration.enable if @time_enabled
    end

    private def trace_rules(grammar : Grammar) : Nil
      return unless @rules
      return if @only_explicit_rules
      return unless io = @io

      io << "Grammar rules:" << "\n"
      grammar.rules.each { |rule| io << rule.display_name << "\n" }
    end

    private def trace_only_explicit_rules(grammar : Grammar) : Nil
      return unless @only_explicit_rules
      return unless io = @io

      io << "Grammar rules:" << "\n"
      grammar.rules.each do |rule|
        lhs = rule.lhs
        next unless lhs
        next if lhs.first_set.empty?
        io << rule.display_name_without_action << "\n"
      end
    end

    private def trace_actions(grammar : Grammar) : Nil
      return unless @actions
      return unless io = @io

      io << "Grammar rules with actions:" << "\n"
      grammar.rules.each { |rule| io << rule.with_actions << "\n" }
    end

    private def previous_symbol_for_trace(state : State) : Grammar::Symbol?
      item = state.kernels.first?
      return nil unless item
      item.previous_sym || item.rule.rhs.last?
    end
  end
end
