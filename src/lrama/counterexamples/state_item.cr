module Lrama
  class Counterexamples
    class StateItem
      getter id : Int32
      getter state : State
      getter item : State::Item

      def initialize(@id : Int32, @state : State, @item : State::Item)
      end

      def type
        case
        when item.start_item?
          :start
        when item.beginning_of_rule?
          :production
        else
          :transition
        end
      end
    end
  end
end
