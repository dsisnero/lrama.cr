module Lrama
  class State
    class Action
      class Shift
        getter from_state : State
        getter next_sym : Grammar::Symbol
        getter to_items : Array(Item)
        getter to_state : State
        property not_selected : Bool?

        def initialize(
          @from_state : State,
          @next_sym : Grammar::Symbol,
          @to_items : Array(Item),
          @to_state : State,
        )
        end

        def clear_conflicts
          @not_selected = nil
        end
      end
    end
  end
end
