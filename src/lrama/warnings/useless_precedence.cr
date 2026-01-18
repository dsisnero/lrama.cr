module Lrama
  class Warnings
    class UselessPrecedence
      def initialize(@logger : Logger, @warnings : Bool)
      end

      def warn(grammar : Grammar, _states : States)
        return unless @warnings

        grammar.precedences.each do |precedence|
          next if precedence.used_by?
          @logger.warn("Precedence #{precedence.s_value} (line: #{precedence.lineno}) is defined but not used in any rule.")
        end
      end
    end
  end
end
