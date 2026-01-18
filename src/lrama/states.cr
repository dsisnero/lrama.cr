module Lrama
  class States
    include Tracer::Duration

    getter states : Array(State)

    def initialize(@grammar : Grammar, @tracer : Tracer = Tracer.new)
      @states = [] of State
    end

    def compute
      report_duration(:compute_lr0_states) { compute_lr0_states }
    end

    def states_count
      @states.size
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
  end
end
