module Lrama
  class Warnings
    class RedefinedRules
      def initialize(@logger : Logger, @warnings : Bool)
      end

      def warn(grammar : Grammar)
        return unless @warnings

        grammar.parameterized_resolver.redefined_rules.each do |rule|
          @logger.warn("parameterized rule redefined: #{rule}")
        end
      end
    end
  end
end
