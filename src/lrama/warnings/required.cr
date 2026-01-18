module Lrama
  class Warnings
    class Required
      def initialize(@logger : Logger, @warnings : Bool = false)
      end

      def warn(grammar : Grammar)
        return unless @warnings
        return unless grammar.required?

        @logger.warn("currently, %require is simply valid as a grammar but does nothing")
      end
    end
  end
end
