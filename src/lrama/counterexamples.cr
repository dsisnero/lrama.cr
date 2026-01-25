require "set"

require "./counterexamples/derivation"
require "./counterexamples/example"
require "./counterexamples/node"
require "./counterexamples/path"
require "./counterexamples/state_item"
require "./counterexamples/triple"

module Lrama
  class TimeoutError < Exception
  end

  # See: https://www.cs.cornell.edu/andru/papers/cupex/cupex.pdf
  #      4. Constructing Nonunifying Counterexamples
  class Counterexamples
    PathSearchTimeLimit =  10
    CumulativeTimeLimit = 120

    getter transitions : Hash(Tuple(StateItem, Grammar::Symbol), StateItem)
    getter productions : Hash(StateItem, Set(StateItem))

    def initialize(@states : States)
      @iterate_count = 0
      @total_duration = 0.0
      @exceed_cumulative_time_limit = false
      @triples = {} of Tuple(Int32, Bitmap::Bitmap) => Triple
      @state_items = {} of Tuple(State, State::Item) => StateItem
      @transitions = {} of Tuple(StateItem, Grammar::Symbol) => StateItem
      @reverse_transitions = {} of Tuple(StateItem, Grammar::Symbol) => Set(StateItem)
      @productions = {} of StateItem => Set(StateItem)
      @reverse_productions = {} of Tuple(State, Grammar::Symbol) => Set(StateItem)
      setup_state_items
      setup_transitions
      setup_productions
    end

    def to_s
      "#<Counterexamples>"
    end

    def inspect
      to_s
    end

    def compute(conflict_state : State) : Array(Example)
      examples = [] of Example

      conflict_state.conflicts.each do |conflict|
        next if @exceed_cumulative_time_limit

        begin
          example = case conflict
                    when State::ShiftReduceConflict
                      shift_reduce_example(conflict_state, conflict)
                    when State::ReduceReduceConflict
                      reduce_reduce_examples(conflict_state, conflict)
                    end
          examples << example if example
        rescue ex : TimeoutError
          STDERR.puts "Counterexamples calculation for state #{conflict_state.id} #{ex.message} with #{@iterate_count} iteration"
          increment_total_duration(PathSearchTimeLimit)
        end
      end

      examples
    end

    private def get_state_item(state : State, item : State::Item)
      @state_items[{state, item}]
    end

    private def setup_state_items
      @state_items = {} of Tuple(State, State::Item) => StateItem
      count = 0

      @states.states.each do |state|
        state.items.each do |item|
          @state_items[{state, item}] = StateItem.new(count, state, item)
          count += 1
        end
      end
    end

    private def setup_transitions
      @transitions = {} of Tuple(StateItem, Grammar::Symbol) => StateItem
      @reverse_transitions = {} of Tuple(StateItem, Grammar::Symbol) => Set(StateItem)

      @states.states.each do |src_state|
        trans = {} of Grammar::Symbol => State
        src_state.transitions.each do |transition|
          trans[transition.next_sym] = transition.to_state
        end

        src_state.items.each do |src_item|
          next if src_item.end_of_rule?
          sym = src_item.next_sym
          next unless sym
          dest_state = trans[sym]
          next unless dest_state

          dest_state.kernels.each do |dest_item|
            next unless src_item.rule == dest_item.rule
            next unless src_item.position + 1 == dest_item.position

            src_state_item = get_state_item(src_state, src_item)
            dest_state_item = get_state_item(dest_state, dest_item)

            @transitions[{src_state_item, sym}] = dest_state_item

            key = {dest_state_item, sym}
            @reverse_transitions[key] ||= Set(StateItem).new
            @reverse_transitions[key] << src_state_item
          end
        end
      end
    end

    private def setup_productions
      @productions = {} of StateItem => Set(StateItem)
      @reverse_productions = {} of Tuple(State, Grammar::Symbol) => Set(StateItem)

      @states.states.each do |state|
        by_symbol = {} of Grammar::Symbol => Set(StateItem)

        state.closure.each do |item|
          lhs = item.rule.lhs || raise "Rule lhs missing"
          by_symbol[lhs] ||= Set(StateItem).new
          by_symbol[lhs] << get_state_item(state, item)
        end

        state.items.each do |item|
          next if item.end_of_rule?
          next_sym = item.next_sym
          next unless next_sym
          next if next_sym.term?

          state_item = get_state_item(state, item)
          @productions[state_item] = by_symbol[next_sym]

          key = {state, next_sym}
          @reverse_productions[key] ||= Set(StateItem).new
          @reverse_productions[key] << state_item
        end
      end
    end

    private def get_triple(state_item : StateItem, precise_lookahead_set : Bitmap::Bitmap)
      key = {state_item.id, precise_lookahead_set}
      @triples[key] ||= Triple.new(state_item, precise_lookahead_set)
    end

    private def shift_reduce_example(conflict_state : State, conflict : State::ShiftReduceConflict)
      conflict_symbol = conflict.symbols.first?
      return unless conflict_symbol

      shift_conflict_item = conflict_state.items.find { |item| item.next_sym == conflict_symbol }
      return unless shift_conflict_item

      path2 = with_timeout("#shortest_path:") do
        shortest_path(conflict_state, conflict.reduce.item, conflict_symbol)
      end
      path1 = with_timeout("#find_shift_conflict_shortest_path:") do
        find_shift_conflict_shortest_path(path2, conflict_state, shift_conflict_item)
      end

      return unless path1 && path2
      Example.new(path1, path2, conflict, conflict_symbol, self)
    end

    private def reduce_reduce_examples(conflict_state : State, conflict : State::ReduceReduceConflict)
      conflict_symbol = conflict.symbols.first?
      return unless conflict_symbol

      path1 = with_timeout("#shortest_path:") do
        shortest_path(conflict_state, conflict.reduce1.item, conflict_symbol)
      end
      path2 = with_timeout("#shortest_path:") do
        shortest_path(conflict_state, conflict.reduce2.item, conflict_symbol)
      end

      return unless path1 && path2
      Example.new(path1, path2, conflict, conflict_symbol, self)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def find_shift_conflict_shortest_path(
      reduce_state_items : Array(StateItem)?,
      conflict_state : State,
      conflict_item : State::Item,
    )
      time1 = Time.instant
      @iterate_count = 0

      target_state_item = get_state_item(conflict_state, conflict_item)
      result = [target_state_item]
      reversed_state_items = (reduce_state_items || [] of StateItem).reverse
      i = 0

      while state_item = reversed_state_items[i]?
        j = i + 1
        pending_index = j

        while prev_state_item = reversed_state_items[j]?
          break unless prev_state_item.type == :production
          j += 1
        end

        if target_state_item == state_item || target_state_item.item.start_item?
          result.concat(reversed_state_items[pending_index..-1] || [] of StateItem)
          break
        end

        if target_state_item.type == :production
          queue = [] of Node(StateItem)
          queue << Node(StateItem).new(target_state_item, nil)

          while sis = queue.shift?
            @iterate_count += 1
            si = sis.elem

            if si.item.start_item?
              items = Node(StateItem).to_a(sis).reverse
              items.shift?
              result.concat(items)
              target_state_item = si
              break
            end

            if si.type == :production
              lhs = si.item.rule.lhs || raise "Rule lhs missing"
              key = {si.state, lhs}
              @reverse_productions[key].each do |prev_item|
                queue << Node(StateItem).new(prev_item, sis)
              end
            else
              prev_sym = si.item.previous_sym
              next unless prev_sym
              key = {si, prev_sym}
              @reverse_transitions[key].each do |prev_target_state_item|
                next if prev_state_item && prev_target_state_item.state != prev_state_item.state
                items = Node(StateItem).to_a(sis).reverse
                items.shift?
                result.concat(items)
                result << prev_target_state_item
                target_state_item = prev_target_state_item
                i = j
                queue.clear
                break
              end
            end
          end
        else
          prev_sym = target_state_item.item.previous_sym
          if prev_sym
            key = {target_state_item, prev_sym}
            @reverse_transitions[key].each do |prev_target_state_item|
              next if prev_state_item && prev_target_state_item.state != prev_state_item.state
              result << prev_target_state_item
              target_state_item = prev_target_state_item
              i = j
              break
            end
          end
        end
      end

      duration = (Time.instant - time1).total_seconds
      increment_total_duration(duration)

      if Tracer::Duration.enabled?
        STDERR.puts sprintf("  %s %10.5f s", "find_shift_conflict_shortest_path #{@iterate_count} iteration", duration)
      end

      result.reverse
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def reachable_state_items(target : StateItem)
      result = Set(StateItem).new
      queue = [target]

      while state_item = queue.shift?
        next if result.includes?(state_item)
        result << state_item

        if prev_sym = state_item.item.previous_sym
          @reverse_transitions[{state_item, prev_sym}]?.try do |prev_items|
            prev_items.each { |prev| queue << prev }
          end
        end

        if state_item.item.beginning_of_rule?
          lhs = state_item.item.rule.lhs || raise "Rule lhs missing"
          @reverse_productions[{state_item.state, lhs}]?.try do |prev_items|
            prev_items.each { |prev| queue << prev }
          end
        end
      end

      result
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def shortest_path(conflict_state : State, conflict_reduce_item : State::Item, conflict_term : Grammar::Symbol)
      time1 = Time.instant
      @iterate_count = 0

      queue = [] of Tuple(Triple, Path)
      visited = Set(Triple).new

      start_state = @states.states.first
      raise "No start state found" unless start_state
      raise "BUG: Start state should be just one kernel." if start_state.kernels.size != 1

      conflict_term_number = conflict_term.number || raise "Conflict term number missing"
      conflict_term_bit = Bitmap.from_integer(conflict_term_number)
      reachable = reachable_state_items(get_state_item(conflict_state, conflict_reduce_item))

      eof_number = @states.eof_symbol.number || raise "EOF symbol number missing"
      start = get_triple(get_state_item(start_state, start_state.kernels.first), Bitmap.from_integer(eof_number))
      queue << {start, Path.new(start.state_item, nil)}

      while entry = queue.shift?
        triple, path = entry
        @iterate_count += 1

        if triple.state == conflict_state && triple.item == conflict_reduce_item && !(triple.l & conflict_term_bit).empty?
          state_items = [path.state_item]
          while path = path.parent
            state_items << path.state_item
          end

          duration = (Time.instant - time1).total_seconds
          increment_total_duration(duration)

          if Tracer::Duration.enabled?
            STDERR.puts sprintf("  %s %10.5f s", "shortest_path #{@iterate_count} iteration", duration)
          end

          return state_items.reverse
        end

        if next_sym = triple.item.next_sym
          next_state_item = @transitions[{triple.state_item, next_sym}]?
          if next_state_item && reachable.includes?(next_state_item)
            t = get_triple(next_state_item, triple.l)
            unless visited.includes?(t)
              visited << t
              queue << {t, Path.new(t.state_item, path)}
            end
          end
        end

        @productions[triple.state_item]?.try do |candidate_items|
          candidate_items.each do |state_item_entry|
            next unless reachable.includes?(state_item_entry)
            l = follow_l(triple.item, triple.l)
            t = get_triple(state_item_entry, l)
            unless visited.includes?(t)
              visited << t
              queue << {t, Path.new(t.state_item, path)}
            end
          end
        end
      end

      nil
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def follow_l(item : State::Item, current_l : Bitmap::Bitmap)
      case
      when item.number_of_rest_symbols == 1
        current_l
      when (next_next = item.next_next_sym).nil?
        current_l
      when next_next.term?
        next_next.number_bitmap || Bitmap.from_array([] of Int32)
      when next_next.nullable == false
        next_next.first_set_bitmap || Bitmap.from_array([] of Int32)
      else
        (next_next.first_set_bitmap || Bitmap.from_array([] of Int32)) | follow_l(item.new_by_next_position, current_l)
      end
    end

    private def with_timeout(message : String, &block)
      result_channel = Channel(typeof(block.call)).new
      error_channel = Channel(Exception).new

      spawn do
        begin
          result_channel.send(block.call)
        rescue ex
          error_channel.send(ex)
        end
      end

      select
      when result = result_channel.receive
        result
      when ex = error_channel.receive
        raise ex
      when timeout(PathSearchTimeLimit.seconds)
        raise TimeoutError.new(message + " timeout of #{PathSearchTimeLimit} sec exceeded")
      end
    end

    private def increment_total_duration(duration : Float64 | Int32 | Int64)
      @total_duration += duration

      if !@exceed_cumulative_time_limit && @total_duration > CumulativeTimeLimit
        @exceed_cumulative_time_limit = true
        STDERR.puts "CumulativeTimeLimit #{CumulativeTimeLimit} sec exceeded then skip following Counterexamples calculation"
      end
    end
  end
end
