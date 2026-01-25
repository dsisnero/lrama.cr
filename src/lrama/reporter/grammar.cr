module Lrama
  class Reporter
    class Grammar
      def initialize(grammar : Bool = false, **_options)
        @grammar = grammar
      end

      def report(io, states)
        return unless @grammar

        io << "Grammar\n"
        last_lhs = nil

        states.rules.each do |rule|
          lhs = rule.lhs || raise "Rule lhs missing"
          rhs =
            if rule.empty_rule?
              "ε"
            else
              rule.rhs.map(&.display_name).join(" ")
            end

          if lhs == last_lhs
            io << sprintf("%5d %s| %s", rule.id || 0, " " * lhs.display_name.size, rhs) << "\n"
          else
            io << "\n"
            io << sprintf("%5d %s: %s", rule.id || 0, lhs.display_name, rhs) << "\n"
          end

          last_lhs = lhs
        end

        io << "\n\n"
      end
    end
  end
end
