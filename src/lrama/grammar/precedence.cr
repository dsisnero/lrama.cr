module Lrama
  class Grammar
    class Precedence
      getter symbol : Grammar::Symbol
      getter s_value : String
      getter type : ::Symbol
      getter precedence : Int32
      getter lineno : Int32

      def initialize(
        @symbol : Grammar::Symbol,
        @s_value : String,
        @type : ::Symbol,
        @precedence : Int32,
        @lineno : Int32,
      )
      end
    end
  end
end
