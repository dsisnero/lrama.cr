module Lrama
  class Counterexamples
    class Example
      getter path1 : Array(StateItem)
      getter path2 : Array(StateItem)
      getter conflict : State::ShiftReduceConflict | State::ReduceReduceConflict
      getter conflict_symbol : Grammar::Symbol

      @derivations1 : Derivation?
      @derivations2 : Derivation?

      def initialize(
        @path1 : Array(StateItem),
        @path2 : Array(StateItem),
        @conflict : State::ShiftReduceConflict | State::ReduceReduceConflict,
        @conflict_symbol : Grammar::Symbol,
        @counterexamples : Counterexamples,
      )
      end

      def type
        @conflict.type
      end

      def path1_item
        @path1.last.item
      end

      def path2_item
        @path2.last.item
      end

      def derivations1
        @derivations1 ||= build_derivations(@path1)
      end

      def derivations2
        @derivations2 ||= build_derivations(@path2)
      end

      # ameba:disable Metrics/CyclomaticComplexity
      private def build_derivations(state_items : Array(StateItem))
        derivation = nil.as(Derivation?)
        current = :production
        last_state_item = state_items.last
        lookahead_sym = last_state_item.item.end_of_rule? ? @conflict_symbol : nil

        state_items.reverse_each do |state_item_entry|
          item = state_item_entry.item

          case current
          when :production
            derivation = Derivation.new(item, derivation)
            case state_item_entry.type
            when :start
              current = :start
            when :transition
              current = :transition
            when :production
              current = :production
            else
              raise "Unexpected. #{state_item_entry}"
            end

            if lookahead_sym && (next_next = item.next_next_sym) && next_next.first_set.includes?(lookahead_sym)
              next_sym = item.next_sym || raise "Next symbol missing"
              if si2 = @counterexamples.transitions[{state_item_entry, next_sym}]?
                derivation2 = find_derivation_for_symbol(si2, lookahead_sym)
                if derivation && derivation2
                  derivation.right = derivation2
                end
              end
              lookahead_sym = nil
            end
          when :transition
            case state_item_entry.type
            when :start
              derivation = Derivation.new(item, derivation)
              current = :start
            when :transition
              current = :transition
            when :production
              current = :production
            else
              raise "Unexpected. #{state_item_entry}"
            end
          else
            raise "BUG: Unknown #{current}"
          end

          break if current == :start
        end

        derivation || raise "Derivation missing"
      end

      # ameba:enable Metrics/CyclomaticComplexity

      private def find_derivation_for_symbol(state_item : StateItem, sym : Grammar::Symbol) : Derivation?
        queue = [] of Array(StateItem)
        queue << [state_item]

        while sis = queue.shift?
          si = sis.last
          next_sym = si.item.next_sym

          if next_sym == sym
            derivation = nil.as(Derivation?)
            sis.reverse_each do |si2|
              derivation = Derivation.new(si2.item, derivation)
            end
            return derivation
          end

          if next_sym && next_sym.nterm? && next_sym.first_set.includes?(sym)
            @counterexamples.productions[si].each do |next_si|
              next if next_si.item.empty_rule?
              next if sis.includes?(next_si)
              queue << (sis + [next_si])
            end

            if next_sym.nullable == true
              if next_si = @counterexamples.transitions[{si, next_sym}]?
                queue << (sis + [next_si])
              end
            end
          end
        end

        nil
      end
    end
  end
end
