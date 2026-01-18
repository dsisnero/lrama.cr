module Lrama
  class Grammar
    class Precedence
      getter symbol : Grammar::Symbol
      getter s_value : String
      getter type : ::Symbol
      getter precedence : Int32
      getter lineno : Int32
      getter used_by_lalr_count : Int32
      getter used_by_ielr_count : Int32

      def initialize(
        @symbol : Grammar::Symbol,
        @s_value : String,
        @type : ::Symbol,
        @precedence : Int32,
        @lineno : Int32,
      )
        @used_by_lalr_count = 0
        @used_by_ielr_count = 0
      end

      def mark_used_by_lalr(_resolved_conflict)
        @used_by_lalr_count += 1
      end

      def mark_used_by_ielr(_resolved_conflict)
        @used_by_ielr_count += 1
      end

      def used_by?
        used_by_lalr? || used_by_ielr?
      end

      def used_by_lalr?
        @used_by_lalr_count > 0
      end

      def used_by_ielr?
        @used_by_ielr_count > 0
      end
    end
  end
end
