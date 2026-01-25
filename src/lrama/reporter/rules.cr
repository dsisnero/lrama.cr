module Lrama
  class Reporter
    class Rules
      def initialize(rules : Bool = false, **_options)
        @rules = rules
      end

      def report(io, states)
        return unless @rules

        used_symbols = states.rules.flat_map(&.rhs)
        unless used_symbols.empty?
          io << "Rule Usage Frequency\n\n"
          counts = Hash(Lrama::Grammar::Symbol, Int32).new(0)
          used_symbols.each { |sym| counts[sym] += 1 }

          counts
            .reject { |sym, _| sym.midrule? }
            .to_a
            .sort_by { |sym, count| {-count, sym.name} }
            .each_with_index do |(sym, count), index|
              io << sprintf("%5d %s (%d times)", index, sym.name, count) << "\n"
            end
          io << "\n\n"
        end

        unused_symbols = states.rules.compact_map(&.lhs).select do |sym|
          !used_symbols.includes?(sym) && (sym.token_id || 0) != 0
        end

        unless unused_symbols.empty?
          io << "#{unused_symbols.size} Unused Rules\n\n"
          unused_symbols.each_with_index do |sym, index|
            io << sprintf("%5d %s", index, sym.display_name) << "\n"
          end
          io << "\n\n"
        end
      end
    end
  end
end
