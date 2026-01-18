module Lrama
  class Warnings
    class ImplicitEmpty
      def initialize(@logger : Logger, @warnings : Bool)
      end

      def warn(grammar : Grammar)
        return unless @warnings

        grammar.rule_builders.each do |builder|
          next unless builder.rhs.empty?
          @logger.warn("warning: empty rule without %empty")
        end
      end
    end
  end
end
