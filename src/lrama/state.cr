require "./state/action"
require "./state/inadequacy_annotation"
require "./state/reduce_reduce_conflict"
require "./state/resolved_conflict"
require "./state/shift_reduce_conflict"
require "./state/item"

module Lrama
  class State
    alias Transition = Action::Shift | Action::Goto

    getter id : Int32
    getter accessing_symbol : Grammar::Symbol
    getter kernels : Array(Item)
    getter items : Array(Item)
    getter items_to_state : Hash(Array(Item), State)
    getter lane_items : Hash(State, Array(Tuple(Item, Item)))
    getter predecessors : Array(State)
    getter closure : Array(Item)
    getter conflicts : Array(ShiftReduceConflict | ReduceReduceConflict)
    getter resolved_conflicts : Array(ResolvedConflict)
    getter default_reduction_rule : Grammar::Rule?
    getter annotation_list : Array(InadequacyAnnotation)
    property ielr_isocores : Array(State) = [] of State
    property? lookaheads_recomputed : Bool
    getter follow_kernel_items : Hash(Action::Goto, Hash(Item, Bool))
    getter always_follows : Hash(Action::Goto, Array(Grammar::Symbol))
    getter goto_follows : Hash(Action::Goto, Array(Grammar::Symbol))

    property _transitions : Array(Tuple(Grammar::Symbol, Array(Item)))
    property reduces : Array(Action::Reduce)

    @lane_items_by_symbol : Hash(Grammar::Symbol, Array(Tuple(Item, Item)))
    @transitions_cache : Array(Transition)?
    @nterm_transitions_cache : Array(Action::Goto)?
    @term_transitions_cache : Array(Action::Shift)?
    @internal_dependencies : Hash(Action::Goto, Array(Action::Goto))
    @successor_dependencies : Hash(Action::Goto, Array(Action::Goto))
    @lookahead_set_filters : Hash(Item, Array(Grammar::Symbol))?
    @inadequacy_list : Hash(Grammar::Symbol, Array(Action::Shift | Action::Reduce))?
    @item_lookahead_set : Hash(Item, Array(Grammar::Symbol))?
    @lalr_isocore : State?
    @lhs_contributions : Hash(Grammar::Symbol, Hash(Grammar::Symbol, Hash(Item, Bool))) = {} of Grammar::Symbol => Hash(Grammar::Symbol, Hash(Item, Bool))

    def initialize(@id : Int32, @accessing_symbol : Grammar::Symbol, @kernels : Array(Item))
      @items = @kernels
      @items_to_state = {} of Array(Item) => State
      @reduces = [] of Action::Reduce
      @_transitions = [] of Tuple(Grammar::Symbol, Array(Item))
      @closure = [] of Item
      @predecessors = [] of State
      @lane_items = {} of State => Array(Tuple(Item, Item))
      @lane_items_by_symbol = {} of Grammar::Symbol => Array(Tuple(Item, Item))
      @transitions_cache = nil
      @nterm_transitions_cache = nil
      @term_transitions_cache = nil
      @conflicts = [] of ShiftReduceConflict | ReduceReduceConflict
      @resolved_conflicts = [] of ResolvedConflict
      @default_reduction_rule = nil
      @internal_dependencies = {} of Action::Goto => Array(Action::Goto)
      @successor_dependencies = {} of Action::Goto => Array(Action::Goto)
      @annotation_list = [] of InadequacyAnnotation
      @lookaheads_recomputed = false
      @follow_kernel_items = {} of Action::Goto => Hash(Item, Bool)
      @always_follows = {} of Action::Goto => Array(Grammar::Symbol)
      @goto_follows = {} of Action::Goto => Array(Grammar::Symbol)
      @lalr_isocore = self
      @ielr_isocores << self
    end

    def ==(other : State)
      id == other.id
    end

    def lalr_isocore : State
      @lalr_isocore || self
    end

    def lalr_isocore=(state : State)
      @lalr_isocore = state
    end

    def closure=(closure : Array(Item))
      @closure = closure
      @items = @kernels + @closure
    end

    def non_default_reduces
      reduces.reject(&.default_reduction)
    end

    def default_reduction_rule=(rule : Grammar::Rule)
      @default_reduction_rule = rule
      reduces.each do |reduce|
        reduce.default_reduction = true if reduce.rule == rule
      end
    end

    def compute_transitions_and_reduces
      transitions = Hash(Grammar::Symbol, Array(Item)).new { |hash, key| hash[key] = [] of Item }
      @lane_items_by_symbol = Hash(Grammar::Symbol, Array(Tuple(Item, Item))).new do |hash, key|
        hash[key] = [] of Tuple(Item, Item)
      end
      reduces = [] of Action::Reduce

      items.each do |item|
        if item.end_of_rule?
          reduces << Action::Reduce.new(item)
        else
          next_sym = item.next_sym
          next unless next_sym
          next_item = item.new_by_next_position
          transitions[next_sym] << next_item
          @lane_items_by_symbol[next_sym] << {item, next_item}
        end
      end

      @_transitions = transitions.to_a.sort_by do |next_sym, _|
        next_sym.number || 0
      end
      @reduces = reduces
      @transitions_cache = nil
      @nterm_transitions_cache = nil
      @term_transitions_cache = nil
    end

    def set_lane_items(next_sym : Grammar::Symbol, next_state : State)
      @lane_items[next_state] = @lane_items_by_symbol[next_sym]
    end

    def set_items_to_state(items : Array(Item), next_state : State)
      @items_to_state[items] = next_state
    end

    def set_look_ahead(rule : Grammar::Rule, look_ahead : Array(Grammar::Symbol))
      reduce_action = reduces.find { |action| action.rule == rule }
      reduce_action.try(&.look_ahead=(look_ahead))
    end

    def set_look_ahead_sources(rule : Grammar::Rule, sources : Hash(Grammar::Symbol, Array(Action::Goto)))
      reduce_action = reduces.find { |action| action.rule == rule }
      reduce_action.try(&.look_ahead_sources=(sources))
    end

    def nterm_transitions
      @nterm_transitions_cache ||= transitions.select(Action::Goto).map(&.as(Action::Goto))
    end

    def term_transitions
      @term_transitions_cache ||= transitions.select(Action::Shift).map(&.as(Action::Shift))
    end

    def selected_term_transitions
      term_transitions.reject(&.not_selected)
    end

    def transitions
      @transitions_cache ||= @_transitions.map do |next_sym, to_items|
        to_state = @items_to_state[to_items]
        if next_sym.term?
          Action::Shift.new(self, next_sym, to_items, to_state)
        else
          Action::Goto.new(self, next_sym, to_items, to_state)
        end
      end
    end

    def transition(sym : Grammar::Symbol)
      if sym.term?
        term_transitions.find(&.next_sym.==(sym)).try(&.to_state) || raise "Can not transit by #{sym} #{self}"
      else
        nterm_transitions.find(&.next_sym.==(sym)).try(&.to_state) || raise "Can not transit by #{sym} #{self}"
      end
    end

    def find_reduce_by_item!(item : Item)
      reduces.find { |reduce| reduce.item == item } || raise "reduce is not found. #{item}"
    end

    def update_transition(transition : Transition, next_state : State)
      set_items_to_state(transition.to_items, next_state)
      next_state.append_predecessor(self)
      update_transitions_caches(transition)
    end

    def update_transitions_caches(transition : Transition)
      new_transition =
        if transition.next_sym.term?
          Action::Shift.new(self, transition.next_sym, transition.to_items, @items_to_state[transition.to_items])
        else
          Action::Goto.new(self, transition.next_sym, transition.to_items, @items_to_state[transition.to_items])
        end

      transitions.delete(transition)
      transitions << new_transition
      @nterm_transitions_cache = nil
      @term_transitions_cache = nil
      if new_transition.is_a?(Action::Goto) && transition.is_a?(Action::Goto)
        if follow_items = @follow_kernel_items.delete(transition)
          @follow_kernel_items[new_transition] = follow_items
        end
        if always_terms = @always_follows.delete(transition)
          @always_follows[new_transition] = always_terms
        end
        if goto_terms = @goto_follows.delete(transition)
          @goto_follows[new_transition] = goto_terms
        end
      end
    end

    def has_conflicts?
      !@conflicts.empty?
    end

    def sr_conflicts
      @conflicts.select { |conflict| conflict.type == :shift_reduce }
    end

    def rr_conflicts
      @conflicts.select { |conflict| conflict.type == :reduce_reduce }
    end

    def clear_conflicts
      @conflicts = [] of ShiftReduceConflict | ReduceReduceConflict
      @resolved_conflicts = [] of ResolvedConflict
      @default_reduction_rule = nil
      term_transitions.each(&.clear_conflicts)
      reduces.each(&.clear_conflicts)
    end

    def split_state?
      lalr_isocore != self
    end

    def propagate_lookaheads(next_state : State)
      next_state.kernels.map do |next_kernel|
        lookahead_sets =
          if next_kernel.position > 1
            kernel = kernels.find(&.predecessor_item_of?(next_kernel))
            item_lookahead_set[kernel]
          else
            goto_follow_set(next_kernel.rule.lhs || raise "Rule lhs missing")
          end
        {next_kernel, lookahead_sets & next_state.lookahead_set_filters[next_kernel]}
      end.to_h
    end

    def compatible?(filtered_lookahead : Hash(Item, Array(Grammar::Symbol)))
      !lookaheads_recomputed? || lalr_isocore.annotation_list.all? do |ann|
        a = ann.dominant_contribution(item_lookahead_set)
        b = ann.dominant_contribution(filtered_lookahead)
        a.nil? || b.nil? || a == b
      end
    end

    def lookahead_set_filters
      @lookahead_set_filters ||= kernels.map do |kernel|
        {kernel, lalr_isocore.annotation_list.select(&.contributed?(kernel)).map(&.token)}
      end.to_h
    end

    def inadequacy_list : Hash(Grammar::Symbol, Array(Action::Shift | Action::Reduce))
      cached = @inadequacy_list
      return cached if cached

      list = {} of Grammar::Symbol => Array(Action::Shift | Action::Reduce)
      term_transitions.each do |shift|
        list[shift.next_sym] ||= [] of Action::Shift | Action::Reduce
        list[shift.next_sym] << shift
      end
      reduces.each do |reduce|
        lookahead = reduce.look_ahead
        next unless lookahead
        lookahead.each do |token|
          list[token] ||= [] of Action::Shift | Action::Reduce
          list[token] << reduce
        end
      end

      result = list.select { |_, actions| actions.size > 1 }
      @inadequacy_list = result
      result
    end

    def annotate_manifestation
      inadequacy_list.each do |token, actions|
        matrix = actions.map do |action|
          if action.is_a?(Action::Shift)
            {action, nil}
          else
            rule = action.item.rule
            contributions =
              if rule.empty_rule?
                lhs = rule.lhs || raise "Rule lhs missing"
                lhs_contributions(lhs, token)
              else
                kernels.map { |kernel| {kernel, kernel.rule == rule && kernel.end_of_rule?} }.to_h
              end
            {action, contributions}
          end
        end.to_h
        @annotation_list << InadequacyAnnotation.new(self, token, actions, matrix)
      end
    end

    def annotate_predecessor(predecessor : State)
      propagating_list = annotation_list.compact_map do |ann|
        matrix = ann.contribution_matrix.map do |action, contributions|
          if contributions.nil?
            {action, nil}
          elsif first_kernels.any? do |kernel|
                  lhs = kernel.rule.lhs || raise "Rule lhs missing"
                  contributions[kernel]? && predecessor.lhs_contributions(lhs, ann.token).empty?
                end
            {action, nil}
          else
            cs = predecessor.lane_items[self].map do |pred_kernel, kernel|
              lhs = kernel.rule.lhs || raise "Rule lhs missing"
              kernel_contribution = contributions[kernel]?
              contributed =
                if kernel_contribution
                  (kernel.position > 1 && predecessor.item_lookahead_set[pred_kernel].includes?(ann.token)) ||
                    (kernel.position == 1 && predecessor.lhs_contributions(lhs, ann.token)[pred_kernel]? == true)
                else
                  false
                end
              {pred_kernel, contributed}
            end.to_h
            {action, cs}
          end
        end.to_h

        next if matrix.all? { |_, contributions| contributions.nil? || contributions.all? { |_, contributed| !contributed } }
        InadequacyAnnotation.new(ann.state, ann.token, ann.actions, matrix)
      end

      predecessor.append_annotation_list(propagating_list)
    end

    def append_annotation_list(propagating_list : Array(InadequacyAnnotation))
      return if propagating_list.empty?

      annotation_list.each do |ann|
        merging_list = propagating_list.select do |incoming|
          incoming.state == ann.state && incoming.token == ann.token && incoming.actions == ann.actions
        end
        ann.merge_matrix(merging_list.map(&.contribution_matrix))
        propagating_list -= merging_list
      end

      @annotation_list += propagating_list
    end

    def first_kernels
      kernels.select { |kernel| kernel.position == 1 }
    end

    def lhs_contributions(sym : Grammar::Symbol, token : Grammar::Symbol)
      return @lhs_contributions[sym][token] if @lhs_contributions[sym]? && @lhs_contributions[sym][token]?

      transition = nterm_transitions.find { |goto| goto.next_sym == sym }
      @lhs_contributions[sym] ||= {} of Grammar::Symbol => Hash(Item, Bool)
      @lhs_contributions[sym][token] =
        if always_follows[transition].includes?(token)
          {} of Item => Bool
        else
          kernels.map { |kernel| {kernel, follow_kernel_items[transition][kernel] && item_lookahead_set[kernel].includes?(token)} }.to_h
        end
      @lhs_contributions[sym][token]
    end

    def item_lookahead_set : Hash(Item, Array(Grammar::Symbol))
      cached = @item_lookahead_set
      return cached if cached

      result = kernels.map do |kernel|
        value =
          if kernel.rule.lhs.try(&.accept_symbol?)
            [] of Grammar::Symbol
          elsif kernel.position > 1
            prev_items = predecessors_with_item(kernel)
            prev_items.map { |state, item| state.item_lookahead_set[item] }.reduce([] of Grammar::Symbol) { |acc, syms| acc | syms }
          elsif kernel.position == 1
            prev_state = @predecessors.find { |pred| pred.transitions.any? { |transition| transition.next_sym == kernel.rule.lhs } }
            raise "Previous state not found for kernel #{kernel.display_name}" unless prev_state
            goto_action = prev_state.nterm_transitions.find { |goto_entry| goto_entry.next_sym == kernel.rule.lhs }
            raise "Goto not found for #{kernel.rule.lhs} on state #{prev_state.id}" unless goto_action
            prev_state.goto_follows[goto_action]
          else
            [] of Grammar::Symbol
          end
        {kernel, value}
      end.to_h
      @item_lookahead_set = result
      result
    end

    def item_lookahead_set=(set : Hash(Item, Array(Grammar::Symbol)))
      @item_lookahead_set = set
    end

    def predecessors_with_item(item : Item)
      result = [] of Tuple(State, Item)
      @predecessors.each do |pre|
        pre.items.each do |candidate|
          result << {pre, candidate} if candidate.predecessor_item_of?(item)
        end
      end
      result
    end

    def goto_follow_set(nterm_token : Grammar::Symbol)
      return [] of Grammar::Symbol if nterm_token.accept_symbol?
      core = lalr_isocore
      goto_action = core.nterm_transitions.find { |goto_entry| goto_entry.next_sym == nterm_token }
      raise "Goto not found for #{nterm_token} on state #{core.id}" unless goto_action
      @kernels
        .select { |kernel| core.follow_kernel_items[goto_action][kernel] }
        .map { |kernel| item_lookahead_set[kernel] }
        .reduce(core.always_follows[goto_action]) { |result, terms| result | terms }
    end

    def internal_dependencies(goto : Action::Goto)
      return @internal_dependencies[goto] if @internal_dependencies[goto]?

      syms = @items.select do |item|
        item.next_sym == goto.next_sym && item.symbols_after_transition.all?(&.nullable) && item.position == 0
      end.compact_map(&.rule.lhs)
      syms.uniq!
      @internal_dependencies[goto] = nterm_transitions.select { |goto2| syms.includes?(goto2.next_sym) }
    end

    def successor_dependencies(goto : Action::Goto)
      return @successor_dependencies[goto] if @successor_dependencies[goto]?

      @successor_dependencies[goto] = goto.to_state.nterm_transitions.select { |next_goto| next_goto.next_sym.nullable == true }
    end

    def predecessor_dependencies(goto : Action::Goto)
      state_items = [] of Tuple(State, Item)
      @kernels.select do |kernel|
        kernel.next_sym == goto.next_sym && kernel.symbols_after_transition.all?(&.nullable)
      end.each do |item|
        queue = predecessors_with_item(item)
        until queue.empty?
          st, it = queue.pop
          if it.position == 0
            state_items << {st, it}
          else
            st.predecessors_with_item(it).each { |pair| queue << pair }
          end
        end
      end

      state_items.compact_map do |state, item|
        state.nterm_transitions.find { |goto_entry| goto_entry.next_sym == item.rule.lhs }
      end
    end

    def append_predecessor(prev_state : State)
      @predecessors << prev_state
      @predecessors.uniq!
    end
  end
end
