module Lrama
  class Grammar
    class Precedence
      getter symbol : Grammar::Symbol
      getter s_value : String
      getter type : ::Symbol
      getter precedence : Int32
      getter lineno : Int32
      getter used_by_lalr : Array(Object)
      getter used_by_ielr : Array(Object)

      def initialize(
        @symbol : Grammar::Symbol,
        @s_value : String,
        @type : ::Symbol,
        @precedence : Int32,
        @lineno : Int32,
      )
        @used_by_lalr = [] of Object
        @used_by_ielr = [] of Object
      end

      def mark_used_by_lalr(resolved_conflict : Object)
        @used_by_lalr << resolved_conflict
      end

      def mark_used_by_ielr(resolved_conflict : Object)
        @used_by_ielr << resolved_conflict
      end

      def used_by?
        used_by_lalr? || used_by_ielr?
      end

      def used_by_lalr?
        !@used_by_lalr.empty?
      end

      def used_by_ielr?
        !@used_by_ielr.empty?
      end
    end
  end
end
