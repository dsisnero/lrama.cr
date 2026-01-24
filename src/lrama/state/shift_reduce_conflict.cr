module Lrama
  class State
    class ShiftReduceConflict
      getter symbols : Array(Grammar::Symbol)
      getter shift : State::Action::Shift
      getter reduce : State::Action::Reduce

      def initialize(
        @symbols : Array(Grammar::Symbol),
        @shift : State::Action::Shift,
        @reduce : State::Action::Reduce,
      )
      end

      def type
        :shift_reduce
      end
    end
  end
end
