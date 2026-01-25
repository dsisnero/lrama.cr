module Lrama
  class Reporter
    class States
      def initialize(
        @itemsets : Bool = false,
        @lookaheads : Bool = false,
        @solved : Bool = false,
        @counterexamples : Bool = false,
        @verbose : Bool = false,
        **_options,
      )
      end

      def report(io, states, ielr : Bool = false)
        cex = Counterexamples.new(states) if @counterexamples
        states.compute_la_sources_for_conflicted_states
        report_split_states(io, states.states) if ielr

        states.states.each do |state|
          report_state_header(io, state)
          report_items(io, state)
          report_conflicts(io, state)
          report_shifts(io, state)
          report_nonassoc_errors(io, state)
          report_reduces(io, state)
          report_nterm_transitions(io, state)
          report_conflict_resolutions(io, state) if @solved
          report_counterexamples(io, state, cex) if @counterexamples && state.has_conflicts?
          report_verbose_info(io, state, states) if @verbose
          io << "\n"
        end
      end

      private def report_split_states(io, states)
        split_states = states.select(&.split_state?)
        return if split_states.empty?

        io << "Split States\n\n"
        split_states.each do |state|
          io << "    State #{state.id} is split from state #{state.lalr_isocore.id}\n"
        end
        io << "\n"
      end

      private def report_state_header(io, state)
        io << "State #{state.id}\n\n"
      end

      private def report_items(io, state)
        last_lhs = nil
        list = @itemsets ? state.items : state.kernels

        list.sort_by { |item| {item.rule_id, item.position} }.each do |item|
          lhs = item.rule.lhs || raise "Rule lhs missing"
          rhs = item.rule.rhs.map(&.display_name).insert(item.position, "•").join(" ")
          rhs = "ε •" if item.empty_rule?
          label =
            if lhs == last_lhs
              " " * lhs.id.s_value.size + "|"
            else
              "#{lhs.id.s_value}:"
            end

          la = ""
          if @lookaheads && item.end_of_rule?
            reduce = state.find_reduce_by_item!(item)
            look_ahead = reduce.selected_look_ahead
            unless look_ahead.empty?
              la = "  [#{look_ahead.map(&.display_name).join(", ")}]"
            end
          end

          last_lhs = lhs
          io << sprintf("%5i %s %s%s", item.rule_id, label, rhs, la) << "\n"
        end

        io << "\n"
      end

      private def report_conflicts(io, state)
        return if state.conflicts.empty?

        state.conflicts.each do |conflict|
          syms = conflict.symbols.map(&.display_name)
          io << "    Conflict on #{syms.join(", ")}. "

          case conflict
          when State::ShiftReduceConflict
            shift_lhs = conflict.reduce.item.rule.lhs || raise "Rule lhs missing"
            io << "shift/reduce(#{shift_lhs.display_name})\n"
            sources = conflict.reduce.look_ahead_sources
            if sources
              conflict.symbols.each do |token|
                sources[token]?.try do |gotos|
                  gotos.each do |goto|
                    io << "      #{token.display_name} comes from state #{goto.from_state.id} goto by #{goto.next_sym.display_name}\n"
                  end
                end
              end
            end
          when State::ReduceReduceConflict
            reduce1_lhs = conflict.reduce1.item.rule.lhs || raise "Rule lhs missing"
            reduce2_lhs = conflict.reduce2.item.rule.lhs || raise "Rule lhs missing"
            io << "reduce(#{reduce1_lhs.display_name})/reduce(#{reduce2_lhs.display_name})\n"
            sources1 = conflict.reduce1.look_ahead_sources
            sources2 = conflict.reduce2.look_ahead_sources
            conflict.symbols.each do |token|
              if sources1
                sources1[token]?.try do |gotos|
                  gotos.each do |goto|
                    io << "      #{token.display_name} comes from state #{goto.from_state.id} goto by #{goto.next_sym.display_name}\n"
                  end
                end
              end
              if sources2
                sources2[token]?.try do |gotos|
                  gotos.each do |goto|
                    io << "      #{token.display_name} comes from state #{goto.from_state.id} goto by #{goto.next_sym.display_name}\n"
                  end
                end
              end
            end
          else
            raise "Unknown conflict type #{conflict.type}"
          end

          io << "\n"
        end

        io << "\n"
      end

      private def report_shifts(io, state)
        shifts = state.term_transitions.reject(&.not_selected)
        return if shifts.empty?

        max_len = shifts.max_of(&.next_sym.display_name.size)
        shifts.each do |shift|
          io << "    #{shift.next_sym.display_name.ljust(max_len)}  shift, and go to state #{shift.to_state.id}\n"
        end

        io << "\n"
      end

      private def report_nonassoc_errors(io, state)
        errors = state.resolved_conflicts.select { |resolved| resolved.which == :error }.map(&.symbol.display_name)
        return if errors.empty?

        max_len = errors.max_of(&.size)
        errors.each do |name|
          io << "    #{name.ljust(max_len)}  error (nonassociative)\n"
        end

        io << "\n"
      end

      private def report_reduces(io, state)
        reduce_pairs = [] of Tuple(Lrama::Grammar::Symbol, State::Action::Reduce)
        state.non_default_reduces.each do |reduce|
          reduce.look_ahead.try do |terms|
            terms.each { |term| reduce_pairs << {term, reduce} }
          end
        end

        return if reduce_pairs.empty? && !state.default_reduction_rule

        pair_max = reduce_pairs.max_of? { |term, _| term.display_name.size } || 0
        default_len = state.default_reduction_rule ? "$default".size : 0
        max_len = {pair_max, default_len}.max

        reduce_pairs.sort_by { |term, _| term.number || 0 }.each do |term, reduce|
          rule = reduce.item.rule
          lhs = rule.lhs || raise "Rule lhs missing"
          rule_id = rule.id || 0
          io << "    #{term.display_name.ljust(max_len)}  reduce using rule #{rule_id} (#{lhs.display_name})\n"
        end

        if rule = state.default_reduction_rule
          label = "$default".ljust(max_len)
          if rule.initial_rule?
            io << "    #{label}  accept\n"
          else
            lhs = rule.lhs || raise "Rule lhs missing"
            rule_id = rule.id || 0
            io << "    #{label}  reduce using rule #{rule_id} (#{lhs.display_name})\n"
          end
        end

        io << "\n"
      end

      private def report_nterm_transitions(io, state)
        return if state.nterm_transitions.empty?

        goto_transitions = state.nterm_transitions.sort_by { |goto| goto.next_sym.number || 0 }
        max_len = goto_transitions.max_of(&.next_sym.id.s_value.size)
        goto_transitions.each do |goto|
          io << "    #{goto.next_sym.id.s_value.ljust(max_len)}  go to state #{goto.to_state.id}\n"
        end

        io << "\n"
      end

      private def report_conflict_resolutions(io, state)
        return if state.resolved_conflicts.empty?

        state.resolved_conflicts.each do |resolved|
          io << "    #{resolved.report_message}\n"
        end

        io << "\n"
      end

      private def report_counterexamples(io, state, cex)
        return unless cex

        examples = cex.compute(state)
        examples.each do |example|
          is_shift_reduce = example.type == :shift_reduce
          label0 = is_shift_reduce ? "shift/reduce" : "reduce/reduce"
          label1 = is_shift_reduce ? "Shift derivation" : "First Reduce derivation"
          label2 = is_shift_reduce ? "Reduce derivation" : "Second Reduce derivation"

          io << "    #{label0} conflict on token #{example.conflict_symbol.id.s_value}:\n"
          io << "        #{example.path1_item}\n"
          io << "        #{example.path2_item}\n"
          io << "      #{label1}\n"
          example.derivations1.render_strings_for_report.each do |str|
            io << "        #{str}\n"
          end
          io << "      #{label2}\n"
          example.derivations2.render_strings_for_report.each do |str|
            io << "        #{str}\n"
          end
        end
      end

      private def report_verbose_info(io, state, states)
        report_direct_read_sets(io, state, states)
        report_reads_relation(io, state, states)
        report_read_sets(io, state, states)
        report_includes_relation(io, state, states)
        report_lookback_relation(io, state, states)
        report_follow_sets(io, state, states)
        report_look_ahead_sets(io, state, states)
      end

      private def report_direct_read_sets(io, state, states)
        io << "  [Direct Read sets]\n"
        direct_read_sets = states.direct_read_sets
        state.nterm_transitions.each do |goto|
          terms = direct_read_sets[goto]?
          next if terms.nil? || terms.empty?

          str = terms.map(&.id.s_value).join(", ")
          io << "    read #{goto.next_sym.id.s_value}  shift #{str}\n"
        end
        io << "\n"
      end

      private def report_reads_relation(io, state, states)
        io << "  [Reads Relation]\n"
        state.nterm_transitions.each do |goto|
          gotos = states.reads_relation[goto]?
          next unless gotos
          gotos.each do |goto2|
            io << "    (State #{goto2.from_state.id}, #{goto2.next_sym.id.s_value})\n"
          end
        end
        io << "\n"
      end

      private def report_read_sets(io, state, states)
        io << "  [Read sets]\n"
        read_sets = states.read_sets
        state.nterm_transitions.each do |goto|
          terms = read_sets[goto]?
          next if terms.nil? || terms.empty?
          terms.each { |sym| io << "    #{sym.id.s_value}\n" }
        end
        io << "\n"
      end

      private def report_includes_relation(io, state, states)
        io << "  [Includes Relation]\n"
        state.nterm_transitions.each do |goto|
          gotos = states.includes_relation[goto]?
          next unless gotos
          gotos.each do |goto2|
            io << "    (State #{state.id}, #{goto.next_sym.id.s_value}) -> (State #{goto2.from_state.id}, #{goto2.next_sym.id.s_value})\n"
          end
        end
        io << "\n"
      end

      private def report_lookback_relation(io, state, states)
        io << "  [Lookback Relation]\n"
        states.rules.each do |rule|
          rule_id = rule.id || 0
          gotos = states.lookback_relation.dig?(state.id, rule_id)
          next unless gotos
          gotos.each do |goto|
            io << "    (Rule: #{rule.display_name}) -> (State #{goto.from_state.id}, #{goto.next_sym.id.s_value})\n"
          end
        end
        io << "\n"
      end

      private def report_follow_sets(io, state, states)
        io << "  [Follow sets]\n"
        follow_sets = states.follow_sets
        state.nterm_transitions.each do |goto|
          terms = follow_sets[goto]?
          next unless terms
          terms.each do |sym|
            io << "    #{goto.next_sym.id.s_value} -> #{sym.id.s_value}\n"
          end
        end
        io << "\n"
      end

      private def report_look_ahead_sets(io, state, states)
        io << "  [Look-Ahead Sets]\n"
        look_ahead_rules = [] of Tuple(Lrama::Grammar::Rule, Array(Lrama::Grammar::Symbol))
        states.rules.each do |rule|
          rule_id = rule.id || 0
          syms = states.la.dig?(state.id, rule_id)
          next unless syms
          look_ahead_rules << {rule, syms}
        end

        return if look_ahead_rules.empty?

        symbols = look_ahead_rules.flat_map { |_, syms| syms }
        max_len = symbols.max_of(&.id.s_value.size)
        look_ahead_rules.each do |rule, syms|
          syms.each do |sym|
            lhs = rule.lhs || raise "Rule lhs missing"
            rule_id = rule.id || 0
            io << "    #{sym.id.s_value.ljust(max_len)}  reduce using rule #{rule_id} (#{lhs.id.s_value})\n"
          end
        end

        io << "\n"
      end
    end
  end
end
