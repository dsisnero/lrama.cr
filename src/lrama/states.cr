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
      report_duration(:compute_conflicts) { compute_conflicts(:lalr) }
      report_duration(:compute_default_reduction) { compute_default_reduction }
    end

    def compute_ielr
      report_duration(:clear_conflicts) { clear_conflicts }
      report_duration(:compute_predecessors) { compute_predecessors }
      report_duration(:compute_follow_kernel_items) { compute_follow_kernel_items }
      report_duration(:compute_always_follows) { compute_always_follows }
      report_duration(:compute_goto_follows) { compute_goto_follows }
      report_duration(:compute_inadequacy_annotations) { compute_inadequacy_annotations }
      report_duration(:split_states) { split_states }
      report_duration(:clear_look_ahead_sets) { clear_look_ahead_sets }
      report_duration(:compute_look_ahead_sets) { compute_look_ahead_sets }
      report_duration(:compute_conflicts) { compute_conflicts(:ielr) }
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

    def symbols
      @grammar.symbols
    end

    def terms
      @grammar.terms
    end

    def nterms
      @grammar.nterms
    end

    def rules
      @grammar.rules
    end

    def precedences
      @grammar.precedences
    end

    def ielr_defined?
      @grammar.ielr_defined?
    end

    def reads_relation
      @reads_relation
    end

    def includes_relation
      @includes_relation
    end

    def lookback_relation
      @lookback_relation
    end

    def direct_read_sets
      @direct_read_sets.transform_values { |bitmap| bitmap_to_terms(bitmap) }
    end

    def read_sets
      @read_sets.transform_values { |bitmap| bitmap_to_terms(bitmap) }
    end

    def follow_sets
      @follow_sets.transform_values { |bitmap| bitmap_to_terms(bitmap) }
    end

    def la
      @la.transform_values do |second_hash|
        second_hash.transform_values { |bitmap| bitmap_to_terms(bitmap) }
      end
    end

    def compute_la_sources_for_conflicted_states
      reflexive = {} of State::Action::Goto => Array(State::Action::Goto)
      @states.each do |state|
        state.nterm_transitions.each do |goto|
          reflexive[goto] = [goto]
        end
      end

      read_sets = Digraph(State::Action::Goto, Array(State::Action::Goto)).new(nterm_transitions, @reads_relation, reflexive).compute
      follow_sets = Digraph(State::Action::Goto, Array(State::Action::Goto)).new(nterm_transitions, @includes_relation, read_sets).compute

      @states.select(&.has_conflicts?).each do |state|
        lookback_relation_on_state = @lookback_relation[state.id]?
        next unless lookback_relation_on_state
        @grammar.rules.each do |rule|
          rule_id = rule.id || 0
          ary = lookback_relation_on_state[rule_id]?
          next unless ary

          sources = {} of Grammar::Symbol => Array(State::Action::Goto)
          ary.each do |goto|
            source = follow_sets[goto]?
            next unless source

            source.each do |goto2|
              tokens = direct_read_sets[goto2]?
              next unless tokens
              tokens.each do |token|
                sources[token] ||= [] of State::Action::Goto
                sources[token] |= [goto2]
              end
            end
          end

          state.set_look_ahead_sources(rule, sources)
        end
      end
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

    private def compute_conflicts(lr_type : Symbol)
      compute_shift_reduce_conflicts(lr_type)
      compute_reduce_reduce_conflicts
    end

    private def compute_shift_reduce_conflicts(lr_type : Symbol)
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
              mark_precedences_used(lr_type, shift_prec, reduce_prec, resolved)
            when shift_prec > reduce_prec
              resolved = State::ResolvedConflict.new(state, sym, reduce, :shift, false)
              state.resolved_conflicts << resolved
              reduce.add_not_selected_symbol(sym)
              mark_precedences_used(lr_type, shift_prec, reduce_prec, resolved)
            else
              case sym.precedence.try(&.type)
              when :precedence
                state.conflicts << State::ShiftReduceConflict.new([sym], shift, reduce)
              when :right
                resolved = State::ResolvedConflict.new(state, sym, reduce, :shift, true)
                state.resolved_conflicts << resolved
                reduce.add_not_selected_symbol(sym)
                mark_precedences_used(lr_type, shift_prec, reduce_prec, resolved)
              when :left
                resolved = State::ResolvedConflict.new(state, sym, reduce, :reduce, true)
                state.resolved_conflicts << resolved
                shift.not_selected = true
                mark_precedences_used(lr_type, shift_prec, reduce_prec, resolved)
              when :nonassoc
                resolved = State::ResolvedConflict.new(state, sym, reduce, :error, false)
                state.resolved_conflicts << resolved
                shift.not_selected = true
                reduce.add_not_selected_symbol(sym)
                mark_precedences_used(lr_type, shift_prec, reduce_prec, resolved)
              else
                raise "Unknown precedence type. #{sym}"
              end
            end
          end
        end
      end
    end

    private def mark_precedences_used(
      lr_type : Symbol,
      shift_prec : Grammar::Precedence,
      reduce_prec : Grammar::Precedence,
      resolved_conflict : State::ResolvedConflict,
    )
      case lr_type
      when :lalr
        shift_prec.mark_used_by_lalr(resolved_conflict)
        reduce_prec.mark_used_by_lalr(resolved_conflict)
      when :ielr
        shift_prec.mark_used_by_ielr(resolved_conflict)
        reduce_prec.mark_used_by_ielr(resolved_conflict)
      end
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

    private def clear_conflicts
      @states.each(&.clear_conflicts)
    end

    private def compute_predecessors
      @states.each do |state|
        state.transitions.each do |transition|
          transition.to_state.append_predecessor(state)
        end
      end
    end

    private def compute_follow_kernel_items
      set = nterm_transitions
      relation = compute_goto_internal_relation
      base_function = compute_goto_bitmaps
      Digraph(State::Action::Goto, Bitmap::Bitmap).new(set, relation, base_function).compute.each do |goto, follow_kernel_items|
        state = goto.from_state
        bools = Bitmap.to_bool_array(follow_kernel_items, state.kernels.size)
        state.follow_kernel_items[goto] = state.kernels.map_with_index do |kernel, index|
          {kernel, bools[index]}
        end.to_h
      end
    end

    private def compute_goto_internal_relation
      relations = {} of State::Action::Goto => Array(State::Action::Goto)
      @states.each do |state|
        state.nterm_transitions.each do |goto|
          relations[goto] = state.internal_dependencies(goto)
        end
      end
      relations
    end

    private def compute_goto_bitmaps
      nterm_transitions.map do |goto|
        bools = goto.from_state.kernels.map_with_index do |kernel, index|
          index if kernel.next_sym == goto.next_sym && kernel.symbols_after_transition.all?(&.nullable)
        end.compact
        {goto, Bitmap.from_array(bools)}
      end.to_h
    end

    private def compute_always_follows
      set = nterm_transitions
      relation = compute_goto_successor_or_internal_relation
      base_function = compute_transition_bitmaps
      Digraph(State::Action::Goto, Bitmap::Bitmap).new(set, relation, base_function).compute.each do |goto, always_follows|
        goto.from_state.always_follows[goto] = bitmap_to_terms(always_follows)
      end
    end

    private def compute_goto_successor_or_internal_relation
      relations = {} of State::Action::Goto => Array(State::Action::Goto)
      @states.each do |state|
        state.nterm_transitions.each do |goto|
          relations[goto] = state.successor_dependencies(goto) + state.internal_dependencies(goto)
        end
      end
      relations
    end

    private def compute_transition_bitmaps
      nterm_transitions.map do |goto|
        terms = goto.to_state.term_transitions.map { |shift| shift.next_sym.number || 0 }
        {goto, Bitmap.from_array(terms)}
      end.to_h
    end

    private def compute_goto_follows
      set = nterm_transitions
      relation = compute_goto_internal_or_predecessor_dependencies
      base_function = compute_always_follows_bitmaps
      Digraph(State::Action::Goto, Bitmap::Bitmap).new(set, relation, base_function).compute.each do |goto, goto_follows|
        goto.from_state.goto_follows[goto] = bitmap_to_terms(goto_follows)
      end
    end

    private def compute_goto_internal_or_predecessor_dependencies
      relations = {} of State::Action::Goto => Array(State::Action::Goto)
      @states.each do |state|
        state.nterm_transitions.each do |goto|
          relations[goto] = state.internal_dependencies(goto) + state.predecessor_dependencies(goto)
        end
      end
      relations
    end

    private def compute_always_follows_bitmaps
      nterm_transitions.map do |goto|
        terms = goto.from_state.always_follows[goto].map { |sym| sym.number || 0 }
        {goto, Bitmap.from_array(terms)}
      end.to_h
    end

    private def split_states
      @states.each do |state|
        state.transitions.each do |transition|
          compute_state(state, transition, transition.to_state)
        end
      end
    end

    private def compute_inadequacy_annotations
      @states.each(&.annotate_manifestation)

      queue = @states.reject(&.annotation_list.empty?)
      while curr = queue.shift?
        curr.predecessors.each do |pred|
          cache = pred.annotation_list.dup
          curr.annotate_predecessor(pred)
          queue << pred if cache != pred.annotation_list && !queue.includes?(pred)
        end
      end
    end

    private def merge_lookaheads(state : State, filtered_lookaheads : Hash(State::Item, Array(Grammar::Symbol)))
      return if state.kernels.all? { |item| (filtered_lookaheads[item] - state.item_lookahead_set[item]).empty? }

      state.item_lookahead_set = state.item_lookahead_set.merge(filtered_lookaheads) do |_item, existing, added|
        existing | added
      end
      state.transitions.each do |transition|
        next if transition.to_state.lookaheads_recomputed?
        compute_state(state, transition, transition.to_state)
      end
    end

    private def compute_state(state : State, transition : State::Transition, next_state : State)
      propagating_lookaheads = state.propagate_lookaheads(next_state)
      split_state = next_state.ielr_isocores.find(&.compatible?(propagating_lookaheads))

      if split_state.nil?
        split_state = next_state.lalr_isocore
        new_state = State.new(@states.size, split_state.accessing_symbol, split_state.kernels)
        new_state.closure = split_state.closure
        new_state.compute_transitions_and_reduces
        split_state.transitions.each do |transition_entry|
          new_state.set_items_to_state(transition_entry.to_items, transition_entry.to_state)
        end
        @states << new_state
        new_state.lalr_isocore = split_state
        split_state.ielr_isocores << new_state
        split_state.ielr_isocores.each do |state_entry|
          state_entry.ielr_isocores = split_state.ielr_isocores
        end
        new_state.lookaheads_recomputed = true
        new_state.item_lookahead_set = propagating_lookaheads
        state.update_transition(transition, new_state)
      elsif !split_state.lookaheads_recomputed?
        split_state.lookaheads_recomputed = true
        split_state.item_lookahead_set = propagating_lookaheads
      else
        merge_lookaheads(split_state, propagating_lookaheads)
        if state.items_to_state[transition.to_items].id != split_state.id
          state.update_transition(transition, split_state)
        end
      end
    end

    private def clear_look_ahead_sets
      @direct_read_sets.clear
      @reads_relation.clear
      @read_sets.clear
      @includes_relation.clear
      @lookback_relation.clear
      @follow_sets.clear
      @la.clear
    end
  end
end
