module Lrama
  class State
    class ReduceReduceConflict
      getter symbols : Array(Grammar::Symbol)
      getter reduce1 : State::Action::Reduce
      getter reduce2 : State::Action::Reduce

      def initialize(
        @symbols : Array(Grammar::Symbol),
        @reduce1 : State::Action::Reduce,
        @reduce2 : State::Action::Reduce,
      )
      end

      def type
        :reduce_reduce
      end
    end
  end
end
