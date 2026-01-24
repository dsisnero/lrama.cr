module Lrama
  class Reporter
    class Conflicts
      def report(io, states)
        report_conflicts(io, states)
      end

      private def report_conflicts(io, states)
        has_conflict = false

        states.states.each do |state|
          messages = format_conflict_messages(state.conflicts)
          next if messages.empty?

          has_conflict = true
          io << "State #{state.id} conflicts: #{messages.join(", ")}\n"
        end

        io << "\n\n" if has_conflict
      end

      private def format_conflict_messages(conflicts)
        conflict_types = {
          shift_reduce:  "shift/reduce",
          reduce_reduce: "reduce/reduce",
        }

        conflict_types.keys.compact_map do |type|
          type_conflicts = conflicts.select { |conflict| conflict.type == type }
          next if type_conflicts.empty?
          "#{type_conflicts.size} #{conflict_types[type]}"
        end
      end
    end
  end
end
