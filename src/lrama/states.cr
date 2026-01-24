require "./digraph"

module Lrama
  class States
    include Tracer::Duration

    getter states : Array(State)

    def initialize(@grammar : Grammar, @tracer : Tracer = Tracer.new)
      @states = [] of State
      @direct_read_sets = {} of State::Action::Goto => Bitmap::Bitmap
      @reads_relation = {} of State::Action::Goto => Array(State::Action::Goto)
      @read_sets = {} of State::Action::Goto => Bitmap::Bitmap
      @includes_relation = {} of State::Action::Goto => Array(State::Action::Goto)
      @lookback_relation = {} of Int32 => Hash(Int32, Array(State::Action::Goto))
      @follow_sets = {} of State::Action::Goto => Bitmap::Bitmap
      @la = {} of Int32 => Hash(Int32, Bitmap::Bitmap)
    end

    def compute
      report_duration(:compute_lr0_states) { compute_lr0_states }
      report_duration(:compute_look_ahead_sets) { compute_look_ahead_sets }
      report_duration(:compute_conflicts) { compute_conflicts }
      report_duration(:compute_default_reduction) { compute_default_reduction }
    end

    def states_count
      @states.size
    end

    def sr_conflicts_count
      @states.flat_map(&.sr_conflicts).size
    end

    def rr_conflicts_count
      @states.flat_map(&.rr_conflicts).size
    end

    private def create_state(
      accessing_symbol : Grammar::Symbol,
      kernels : Array(State::Item),
      states_created : Hash(Array(State::Item), State),
    )
      if existing = states_created[kernels]?
        return {existing, false}
      end

      state = State.new(@states.size, accessing_symbol, kernels)
      @states << state
      states_created[kernels] = state
      {state, true}
    end

    private def setup_state(state : State)
      closure = [] of State::Item
      queued = {} of Int32 => Bool
      items = state.kernels.dup

      items.each do |item|
        queued[item.rule_id] = true if item.position == 0
      end

      while item = items.shift?
        if (sym = item.next_sym) && sym.nterm?
          @grammar.find_rules_by_symbol!(sym).each do |rule|
            rule_id = rule.id || raise "Rule id missing"
            next if queued[rule_id]?
            new_item = State::Item.new(rule, 0)
            closure << new_item
            items << new_item
            queued[new_item.rule_id] = true
          end
        end
      end

      closure.sort_by!(&.rule_id)
      state.closure = closure

      @tracer.trace_closure(state)
      state.compute_transitions_and_reduces
    end

    private def enqueue_state(queue : Array(State), state : State)
      @tracer.trace_state_list_append(@states.size, state)
      queue << state
    end

    private def compute_lr0_states
      queue = [] of State
      states_created = {} of Array(State::Item) => State

      start_rule = @grammar.rules.first?
      raise "No rules available to build states" unless start_rule
      start_symbol = @grammar.symbols.first?
      raise "No symbols available to build states" unless start_symbol

      state, _ = create_state(start_symbol, [State::Item.new(start_rule, 0)], states_created)
      enqueue_state(queue, state)

      while state = queue.shift?
        @tracer.trace_state(state)
        setup_state(state)

        state._transitions.each do |next_sym, to_items|
          new_state, created = create_state(next_sym, to_items, states_created)
          state.set_items_to_state(to_items, new_state)
          state.set_lane_items(next_sym, new_state)
          enqueue_state(queue, new_state) if created
        end
      end
    end

    private def nterm_transitions
      transitions = [] of State::Action::Goto
      @states.each do |state|
        state.nterm_transitions.each do |goto|
          transitions << goto
        end
      end
      transitions
    end

    private def compute_look_ahead_sets
      compute_direct_read_sets
      compute_reads_relation
      compute_read_sets
      compute_includes_relation
      compute_lookback_relation
      compute_follow_sets
      compute_la
    end

    private def compute_direct_read_sets
      @states.each do |state|
        state.nterm_transitions.each do |goto|
          terms = goto.to_state.term_transitions.map { |shift| shift.next_sym.number || 0 }
          @direct_read_sets[goto] = Bitmap.from_array(terms)
        end
      end
    end

    private def compute_reads_relation
      @states.each do |state|
        state.nterm_transitions.each do |goto|
          goto.to_state.nterm_transitions.each do |goto2|
            next unless goto2.next_sym.nullable == true
            @reads_relation[goto] ||= [] of State::Action::Goto
            @reads_relation[goto] << goto2
          end
        end
      end
    end

    private def compute_read_sets
      base = nterm_transitions.to_h do |goto|
        {goto, @direct_read_sets[goto]? || Bitmap.from_array([] of Int32)}
      end
      @read_sets = Digraph(State::Action::Goto, Bitmap::Bitmap).new(nterm_transitions, @reads_relation, base).compute
    end

    private def transition(state : State, symbols : Array(Grammar::Symbol))
      symbols.each do |sym|
        state = state.transition(sym)
      end
      state
    end

    private def compute_includes_relation
      @states.each do |state|
        state.nterm_transitions.each do |goto|
          nterm = goto.next_sym
          @grammar.find_rules_by_symbol!(nterm).each do |rule|
            index = rule.rhs.size - 1
            while index > -1
              sym = rule.rhs[index]
              break if sym.term?
              state2 = transition(state, rule.rhs[0...index])
              key = state2.nterm_transitions.find { |goto2| goto2.next_sym.token_id == sym.token_id }
              raise "Goto by #{sym.name} on state #{state2.id} is not found" unless key
              @includes_relation[key] ||= [] of State::Action::Goto
              @includes_relation[key] << goto
              break unless sym.nullable == true
              index -= 1
            end
          end
        end
      end
    end

    private def compute_lookback_relation
      @states.each do |state|
        state.nterm_transitions.each do |goto|
          nterm = goto.next_sym
          @grammar.find_rules_by_symbol!(nterm).each do |rule|
            state2 = transition(state, rule.rhs)
            @lookback_relation[state2.id] ||= {} of Int32 => Array(State::Action::Goto)
            @lookback_relation[state2.id][rule.id || 0] ||= [] of State::Action::Goto
            @lookback_relation[state2.id][rule.id || 0] << goto
          end
        end
      end
    end

    private def compute_follow_sets
      base = nterm_transitions.to_h do |goto|
        {goto, @read_sets[goto]? || Bitmap.from_array([] of Int32)}
      end
      @follow_sets = Digraph(State::Action::Goto, Bitmap::Bitmap).new(nterm_transitions, @includes_relation, base).compute
    end

    private def compute_la
      @states.each do |state|
        lookback_relation_on_state = @lookback_relation[state.id]?
        next unless lookback_relation_on_state
        @grammar.rules.each do |rule|
          rule_id = rule.id || 0
          ary = lookback_relation_on_state[rule_id]?
          next unless ary
          ary.each do |goto|
            follows = @follow_sets[goto]?
            next unless follows
            next if follows.empty?
            @la[state.id] ||= {} of Int32 => Bitmap::Bitmap
            @la[state.id][rule_id] ||= Bitmap.from_array([] of Int32)
            @la[state.id][rule_id] = @la[state.id][rule_id] | follows
            next if state.reduces.size == 1 && state.term_transitions.empty?
            state.set_look_ahead(rule, bitmap_to_terms(@la[state.id][rule_id]))
          end
        end
      end
    end

    private def bitmap_to_terms(bit : Bitmap::Bitmap)
      Bitmap.to_array(bit).map { |number| @grammar.find_symbol_by_number!(number) }
    end

    private def compute_conflicts
      compute_shift_reduce_conflicts
      compute_reduce_reduce_conflicts
    end

    private def compute_shift_reduce_conflicts
      @states.each do |state|
        state.term_transitions.each do |shift|
          state.reduces.each do |reduce|
            sym = shift.next_sym
            lookahead = reduce.look_ahead
            next unless lookahead
            next unless lookahead.includes?(sym)

            shift_prec = sym.precedence
            reduce_prec = reduce.item.rule.precedence

            unless shift_prec && reduce_prec
              state.conflicts << State::ShiftReduceConflict.new([sym], shift, reduce)
              next
            end

            case
            when shift_prec < reduce_prec
              resolved = State::ResolvedConflict.new(state, sym, reduce, :reduce, false)
              state.resolved_conflicts << resolved
              shift.not_selected = true
              mark_precedences_used(shift_prec, reduce_prec, resolved)
            when shift_prec > reduce_prec
              resolved = State::ResolvedConflict.new(state, sym, reduce, :shift, false)
              state.resolved_conflicts << resolved
              reduce.add_not_selected_symbol(sym)
              mark_precedences_used(shift_prec, reduce_prec, resolved)
            else
              case sym.precedence.try(&.type)
              when :precedence
                state.conflicts << State::ShiftReduceConflict.new([sym], shift, reduce)
              when :right
                resolved = State::ResolvedConflict.new(state, sym, reduce, :shift, true)
                state.resolved_conflicts << resolved
                reduce.add_not_selected_symbol(sym)
                mark_precedences_used(shift_prec, reduce_prec, resolved)
              when :left
                resolved = State::ResolvedConflict.new(state, sym, reduce, :reduce, true)
                state.resolved_conflicts << resolved
                shift.not_selected = true
                mark_precedences_used(shift_prec, reduce_prec, resolved)
              when :nonassoc
                resolved = State::ResolvedConflict.new(state, sym, reduce, :error, false)
                state.resolved_conflicts << resolved
                shift.not_selected = true
                reduce.add_not_selected_symbol(sym)
                mark_precedences_used(shift_prec, reduce_prec, resolved)
              else
                raise "Unknown precedence type. #{sym}"
              end
            end
          end
        end
      end
    end

    private def mark_precedences_used(
      shift_prec : Grammar::Precedence,
      reduce_prec : Grammar::Precedence,
      resolved_conflict : State::ResolvedConflict,
    )
      shift_prec.mark_used_by_lalr(resolved_conflict)
      reduce_prec.mark_used_by_lalr(resolved_conflict)
    end

    private def compute_reduce_reduce_conflicts
      @states.each do |state|
        reduces = state.reduces
        (0...reduces.size).each do |i|
          (i + 1...reduces.size).each do |j|
            reduce1 = reduces[i]
            reduce2 = reduces[j]
            la1 = reduce1.look_ahead
            la2 = reduce2.look_ahead
            next unless la1 && la2
            intersection = la1 & la2
            next if intersection.empty?
            state.conflicts << State::ReduceReduceConflict.new(intersection, reduce1, reduce2)
          end
        end
      end
    end

    private def compute_default_reduction
      @states.each do |state|
        next if state.reduces.empty?
        next unless state.conflicts.empty?
        next if state.term_transitions.map(&.next_sym).includes?(@grammar.error_symbol!)
        candidates = state.reduces.map do |reduce|
          {reduce.rule, reduce.rule.id || 0, (reduce.look_ahead || [] of Grammar::Symbol).size}
        end
        selected = candidates.min_by do |entry|
          count = entry[2]
          {-count, entry[1]}
        end
        state.default_reduction_rule = selected[0]
      end
    end
  end
end
