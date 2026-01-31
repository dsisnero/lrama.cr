module Lrama
  class LexerBuilder
    struct Tables
      getter transitions : Array(Array(Int32))
      getter accept : Array(Int32)

      def initialize(@transitions : Array(Array(Int32)), @accept : Array(Int32))
      end
    end

    struct TablesByState
      getter tables : Array(Tables)
      getter states : Array(String)

      def initialize(@tables : Array(Tables), @states : Array(String))
      end
    end

    def initialize(@spec : LexerSpec)
      @states = [] of NFAState
    end

    def build : TablesByState
      start_states = {} of String => Int32
      @spec.states.each do |name|
        start_states[name] = new_state
      end

      @spec.rules.each_with_index do |rule, index|
        fragment = build_nfa(rule.pattern)
        rule.states.each do |state_name|
          start_state = start_states[state_name]?
          next unless start_state
          @states[start_state].epsilons << fragment[:start]
        end
        @states[fragment[:accept]].accept_rule = index
      end

      tables = @spec.states.map do |name|
        start_state = start_states[name]
        DfaBuilder.new(@states, start_state).build
      end
      TablesByState.new(tables, @spec.states)
    end

    private class NFAState
      property epsilons : Array(Int32)
      property transitions : Array(Tuple(LexerSpec::ByteSet, Int32))
      property accept_rule : Int32?

      def initialize
        @epsilons = [] of Int32
        @transitions = [] of Tuple(LexerSpec::ByteSet, Int32)
        @accept_rule = nil
      end
    end

    private def new_state
      @states << NFAState.new
      @states.size - 1
    end

    private def build_nfa(ast : LexerSpec::RegexAst)
      case ast
      when LexerSpec::Sequence
        parts = ast.parts
        return empty_fragment if parts.empty?
        fragment = build_nfa(parts.first)
        parts[1..-1].each do |part|
          next_fragment = build_nfa(part)
          @states[fragment[:accept]].epsilons << next_fragment[:start]
          fragment = {start: fragment[:start], accept: next_fragment[:accept]}
        end
        fragment
      when LexerSpec::Literal
        start_state = new_state
        end_state = new_state
        set = LexerSpec::ByteSet.new
        set.add(ast.byte)
        @states[start_state].transitions << {set, end_state}
        {start: start_state, accept: end_state}
      when LexerSpec::CharClass
        start_state = new_state
        end_state = new_state
        @states[start_state].transitions << {ast.set, end_state}
        {start: start_state, accept: end_state}
      when LexerSpec::AnyChar
        start_state = new_state
        end_state = new_state
        set = LexerSpec::ByteSet.full
        @states[start_state].transitions << {set, end_state}
        {start: start_state, accept: end_state}
      when LexerSpec::Alternation
        start_state = new_state
        end_state = new_state
        ast.options.each do |option|
          fragment = build_nfa(option)
          @states[start_state].epsilons << fragment[:start]
          @states[fragment[:accept]].epsilons << end_state
        end
        {start: start_state, accept: end_state}
      when LexerSpec::Repeat
        build_repeat(ast)
      else
        raise "Unknown lexer AST: #{ast}"
      end
    end

    private def empty_fragment
      start_state = new_state
      end_state = new_state
      @states[start_state].epsilons << end_state
      {start: start_state, accept: end_state}
    end

    private def build_repeat(ast : LexerSpec::Repeat)
      case {ast.min, ast.max}
      when {0, nil} # *
        build_star(ast.node)
      when {1, nil} # +
        build_plus(ast.node)
      when {0, 1} # ?
        build_optional(ast.node)
      else
        build_bounded_repeat(ast.node, ast.min, ast.max)
      end
    end

    private def build_star(node : LexerSpec::RegexAst)
      fragment = build_nfa(node)
      start_state = new_state
      end_state = new_state
      @states[start_state].epsilons << fragment[:start]
      @states[start_state].epsilons << end_state
      @states[fragment[:accept]].epsilons << fragment[:start]
      @states[fragment[:accept]].epsilons << end_state
      {start: start_state, accept: end_state}
    end

    private def build_plus(node : LexerSpec::RegexAst)
      fragment = build_nfa(node)
      start_state = new_state
      end_state = new_state
      @states[start_state].epsilons << fragment[:start]
      @states[fragment[:accept]].epsilons << fragment[:start]
      @states[fragment[:accept]].epsilons << end_state
      {start: start_state, accept: end_state}
    end

    private def build_optional(node : LexerSpec::RegexAst)
      fragment = build_nfa(node)
      start_state = new_state
      end_state = new_state
      @states[start_state].epsilons << fragment[:start]
      @states[start_state].epsilons << end_state
      @states[fragment[:accept]].epsilons << end_state
      {start: start_state, accept: end_state}
    end

    private def build_bounded_repeat(node : LexerSpec::RegexAst, min : Int32, max : Int32?)
      return empty_fragment if min == 0 && max == 0

      if min > 0
        fragment = build_nfa(node)
        start_state = fragment[:start]
        current_accept = fragment[:accept]
        (min - 1).times do
          next_fragment = build_nfa(node)
          @states[current_accept].epsilons << next_fragment[:start]
          current_accept = next_fragment[:accept]
        end
      else
        start_state = new_state
        current_accept = start_state
      end

      if max.nil?
        star_fragment = build_star(node)
        @states[current_accept].epsilons << star_fragment[:start]
        return {start: start_state, accept: star_fragment[:accept]}
      end

      end_state = new_state

      optional_count = max - min
      optional_count.times do
        @states[current_accept].epsilons << end_state
        opt_fragment = build_nfa(node)
        @states[current_accept].epsilons << opt_fragment[:start]
        current_accept = opt_fragment[:accept]
      end
      @states[current_accept].epsilons << end_state
      {start: start_state, accept: end_state}
    end

    private class DfaBuilder
      def initialize(@nfa_states : Array(NFAState), @start_state : Int32)
      end

      def build : Tables
        dfa_states = [] of Array(Int32)
        dfa_accept = [] of Int32
        transitions = [] of Array(Int32)
        queue = [] of Array(Int32)

        start_set = epsilon_closure([@start_state])
        dfa_states << start_set
        dfa_accept << accept_rule_for(start_set)
        queue << start_set

        while current = queue.shift?
          row = Array.new(256, -1)
          current_id = dfa_states.index(current) || raise "DFA state missing"
          256.times do |byte_value|
            move_set = move(current, byte_value.to_u8)
            if move_set.empty?
              row[byte_value] = -1
              next
            end
            closure = epsilon_closure(move_set)
            target_id = dfa_states.index(closure)
            unless target_id
              dfa_states << closure
              dfa_accept << accept_rule_for(closure)
              queue << closure
              target_id = dfa_states.size - 1
            end
            row[byte_value] = target_id
          end
          if transitions.size == current_id
            transitions << row
          else
            transitions[current_id] = row
          end
        end

        Tables.new(transitions, dfa_accept)
      end

      private def epsilon_closure(states : Array(Int32))
        visited = Array.new(@nfa_states.size, false)
        stack = states.dup
        result = [] of Int32
        while state = stack.pop?
          next if visited[state]
          visited[state] = true
          result << state
          @nfa_states[state].epsilons.each { |next_state| stack << next_state }
        end
        result.sort!
        result
      end

      private def move(states : Array(Int32), byte : UInt8)
        result = [] of Int32
        states.each do |state|
          @nfa_states[state].transitions.each do |set, target|
            result << target if set.include?(byte)
          end
        end
        result
      end

      private def accept_rule_for(states : Array(Int32))
        rule = nil.as(Int32?)
        states.each do |state|
          accept = @nfa_states[state].accept_rule
          next unless accept
          rule = accept if rule.nil? || accept < rule
        end
        rule || -1
      end
    end
  end
end
