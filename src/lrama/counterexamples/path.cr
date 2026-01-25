module Lrama
  class Counterexamples
    class Path
      getter state_item : StateItem
      getter parent : Path?

      def initialize(@state_item : StateItem, @parent : Path?)
      end

      def to_s
        "#<Path>"
      end

      def inspect
        to_s
      end
    end
  end
end
