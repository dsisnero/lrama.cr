module Lrama
  class Warnings
    class Conflicts
      def initialize(@logger : Logger, @warnings : Bool)
      end

      def warn(states : States)
        return unless @warnings

        if states.sr_conflicts_count != 0
          @logger.warn("shift/reduce conflicts: #{states.sr_conflicts_count} found")
        end

        if states.rr_conflicts_count != 0
          @logger.warn("reduce/reduce conflicts: #{states.rr_conflicts_count} found")
        end
      end
    end
  end
end
