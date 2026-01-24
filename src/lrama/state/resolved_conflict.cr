module Lrama
  class State
    class ResolvedConflict
      getter state : State
      getter symbol : Grammar::Symbol
      getter reduce : State::Action::Reduce
      getter which : ::Symbol
      getter? resolved_by_precedence : Bool

      def initialize(
        @state : State,
        @symbol : Grammar::Symbol,
        @reduce : State::Action::Reduce,
        @which : ::Symbol,
        @resolved_by_precedence : Bool,
      )
      end

      def report_message
        "Conflict between rule #{reduce.rule.id} and token #{symbol.display_name} #{how_resolved}."
      end

      def report_precedences_message
        "Conflict between reduce by \"#{reduce.rule.display_name}\" and shift #{symbol.display_name} #{how_resolved}."
      end

      private def how_resolved
        sym = symbol.display_name
        rule_prec = reduce.rule.precedence_sym.try(&.display_name)
        case
        when which == :shift && resolved_by_precedence?
          "resolved as #{which} (%right #{sym})"
        when which == :shift
          "resolved as #{which} (#{rule_prec} < #{sym})"
        when which == :reduce && resolved_by_precedence?
          "resolved as #{which} (%left #{sym})"
        when which == :reduce
          "resolved as #{which} (#{sym} < #{rule_prec})"
        when which == :error
          "resolved as an #{which} (%nonassoc #{sym})"
        else
          raise "Unknown direction. #{self}"
        end
      end
    end
  end
end
