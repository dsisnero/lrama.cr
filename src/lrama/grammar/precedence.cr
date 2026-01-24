module Lrama
  class Grammar
    class Precedence
      include Comparable(Precedence)
      getter symbol : Grammar::Symbol
      getter s_value : String
      getter type : ::Symbol
      getter precedence : Int32
      getter lineno : Int32
      getter used_by_lalr_count : Int32
      getter used_by_ielr_count : Int32
      getter used_by_lalr : Array(State::ResolvedConflict)
      getter used_by_ielr : Array(State::ResolvedConflict)

      def initialize(
        @symbol : Grammar::Symbol,
        @s_value : String,
        @type : ::Symbol,
        @precedence : Int32,
        @lineno : Int32,
      )
        @used_by_lalr_count = 0
        @used_by_ielr_count = 0
        @used_by_lalr = [] of State::ResolvedConflict
        @used_by_ielr = [] of State::ResolvedConflict
      end

      def <=>(other : Precedence)
        precedence <=> other.precedence
      end

      def mark_used_by_lalr(resolved_conflict : State::ResolvedConflict)
        @used_by_lalr_count += 1
        @used_by_lalr << resolved_conflict
      end

      def mark_used_by_ielr(resolved_conflict : State::ResolvedConflict)
        @used_by_ielr_count += 1
        @used_by_ielr << resolved_conflict
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
