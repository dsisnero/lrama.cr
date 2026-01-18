require "set"

module Lrama
  class Warnings
    class NameConflicts
      def initialize(@logger : Logger, @warnings : Bool)
      end

      def warn(grammar : Grammar)
        return unless @warnings
        return if grammar.parameterized_rules.empty?

        symbol_names = collect_symbol_names(grammar)
        grammar.parameterized_rules.each do |param_rule|
          next unless symbol_names.includes?(param_rule.name)
          @logger.warn("warning: parameterized rule name \"#{param_rule.name}\" conflicts with symbol name")
        end
      end

      private def collect_symbol_names(grammar : Grammar)
        names = Set(String).new
        grammar.terms.each do |term|
          names << term.id.s_value
          names << term.alias_name if term.alias_name
        end
        grammar.nterms.each do |nterm|
          names << nterm.id.s_value
        end
        names
      end
    end
  end
end
