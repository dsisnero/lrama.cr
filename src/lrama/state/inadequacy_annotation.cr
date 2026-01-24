module Lrama
  class State
    class InadequacyAnnotation
      alias Action = State::Action::Shift | State::Action::Reduce

      getter state : State
      getter token : Grammar::Symbol
      getter actions : Array(Action)
      getter contribution_matrix : Hash(Action, Hash(Item, Bool)?)

      def initialize(
        @state : State,
        @token : Grammar::Symbol,
        @actions : Array(Action),
        @contribution_matrix : Hash(Action, Hash(Item, Bool)?),
      )
      end

      def contributed?(item : Item)
        @contribution_matrix.any? { |_, contributions| contributions && contributions[item]? }
      end

      def merge_matrix(another_matrixes : Array(Hash(Action, Hash(Item, Bool)?)))
        another_matrixes.each do |another_matrix|
          another_matrix.each do |action, another_contributions|
            contributions = @contribution_matrix[action]?
            if contributions && another_contributions
              another_contributions.each do |item, contributed|
                contributions[item] = contributed || contributions[item]? == true
              end
              @contribution_matrix[action] = contributions
            elsif contributions.nil?
              @contribution_matrix[action] = another_contributions
            end
          end
        end
      end

      def dominant_contribution(lookaheads : Hash(Item, Array(Grammar::Symbol)))
        actions = @actions.select do |action|
          contributions = contribution_matrix[action]?
          contributions.nil? || contributions.any? { |item, contributed| contributed && lookaheads[item].includes?(token) }
        end
        return if actions.empty?

        resolve_conflict(actions)
      end

      def resolve_conflict(actions : Array(Action))
        shifts = actions.select(State::Action::Shift)
        reduces = actions.select(State::Action::Reduce)

        shifts.each do |shift|
          reduces.each do |reduce|
            sym = shift.next_sym
            shift_prec = sym.precedence
            reduce_prec = reduce.item.rule.precedence

            next unless shift_prec && reduce_prec

            case
            when shift_prec < reduce_prec
              actions.delete(shift)
            when shift_prec > reduce_prec
              actions.delete(reduce)
            else
              case sym.precedence.try(&.type)
              when :precedence
                # unresolved
              when :right
                actions.delete(reduce)
              when :left
                actions.delete(shift)
              when :nonassoc
                actions.delete(shift)
                actions.delete(reduce)
              else
                raise "Unknown precedence type. #{sym}"
              end
            end
          end
        end

        actions
      end
    end
  end
end
