require "./state/action"
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

    property _transitions : Array(Tuple(Grammar::Symbol, Array(Item)))
    property reduces : Array(Action::Reduce)

    @lane_items_by_symbol : Hash(Grammar::Symbol, Array(Tuple(Item, Item)))
    @transitions_cache : Array(Transition)?
    @nterm_transitions_cache : Array(Action::Goto)?
    @term_transitions_cache : Array(Action::Shift)?

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
    end

    def ==(other : State)
      id == other.id
    end

    def closure=(closure : Array(Item))
      @closure = closure
      @items = @kernels + @closure
    end

    def non_default_reduces
      reduces.reject(&.default_reduction)
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
    end

    def append_predecessor(prev_state : State)
      @predecessors << prev_state
      @predecessors.uniq!
    end
  end
end
