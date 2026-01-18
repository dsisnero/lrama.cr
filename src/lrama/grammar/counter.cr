module Lrama
  class Grammar
    class Counter
      def initialize(@number : Int32)
      end

      def increment
        value = @number
        @number += 1
        value
      end
    end
  end
end
