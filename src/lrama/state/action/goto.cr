module Lrama
  class State
    class Action
      class Goto
        getter from_state : State
        getter next_sym : Grammar::Symbol
        getter to_items : Array(Item)
        getter to_state : State

        def initialize(
          @from_state : State,
          @next_sym : Grammar::Symbol,
          @to_items : Array(Item),
          @to_state : State,
        )
        end
      end
    end
  end
end
