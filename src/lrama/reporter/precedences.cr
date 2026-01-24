module Lrama
  class Reporter
    class Precedences
      def report(io, states)
        report_precedences(io, states)
      end

      private def report_precedences(io, states)
        used_precedences = states.precedences.select(&.used_by?)
        return if used_precedences.empty?

        io << "Precedences\n\n"

        used_precedences.each do |precedence|
          io << "  precedence on #{precedence.symbol.display_name} is used to resolve conflict on\n"

          if precedence.used_by_lalr?
            io << "    LALR\n"
            precedence.used_by_lalr.uniq.sort_by!(&.state.id).each do |resolved|
              io << "      state #{resolved.state.id}. #{resolved.report_precedences_message}\n"
            end
            io << "\n"
          end

          if precedence.used_by_ielr?
            io << "    IELR\n"
            precedence.used_by_ielr.uniq.sort_by!(&.state.id).each do |resolved|
              io << "      state #{resolved.state.id}. #{resolved.report_precedences_message}\n"
            end
            io << "\n"
          end
        end

        io << "\n"
      end
    end
  end
end
