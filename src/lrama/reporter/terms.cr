module Lrama
  class Reporter
    class Terms
      def initialize(terms : Bool = false, **_options)
        @terms = terms
      end

      def report(io, states)
        return unless @terms

        look_aheads = states.states.flat_map do |state|
          state.reduces.compact_map(&.look_ahead).flatten
        end
        next_terms = states.states.flat_map { |state| state.term_transitions.map(&.next_sym) }

        unused_symbols = states.terms.reject do |term|
          (look_aheads + next_terms).includes?(term)
        end

        io << "#{states.terms.size} Terms\n\n"
        io << "#{states.nterms.size} Non-Terminals\n\n"

        unless unused_symbols.empty?
          io << "#{unused_symbols.size} Unused Terms\n\n"
          unused_symbols.each_with_index do |term, index|
            io << sprintf("%5d %s", index, term.id.s_value) << "\n"
          end
          io << "\n\n"
        end
      end
    end
  end
end
