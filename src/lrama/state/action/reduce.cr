module Lrama
  class State
    class Action
      class Reduce
        getter item : Item
        getter look_ahead : Array(Grammar::Symbol)?
        getter look_ahead_sources : Hash(Grammar::Symbol, Array(Action::Goto))?
        getter not_selected_symbols : Array(Grammar::Symbol)

        property default_reduction : Bool?

        def initialize(@item : Item)
          @look_ahead = nil
          @look_ahead_sources = nil
          @not_selected_symbols = [] of Grammar::Symbol
        end

        def rule
          item.rule
        end

        def look_ahead=(look_ahead : Array(Grammar::Symbol))
          @look_ahead = look_ahead
        end

        def look_ahead_sources=(sources : Hash(Grammar::Symbol, Array(Action::Goto)))
          @look_ahead_sources = sources
        end

        def add_not_selected_symbol(sym : Grammar::Symbol)
          @not_selected_symbols << sym
        end

        def selected_look_ahead
          lookahead = look_ahead
          if lookahead
            lookahead - @not_selected_symbols
          else
            [] of Grammar::Symbol
          end
        end

        def clear_conflicts
          @not_selected_symbols = [] of Grammar::Symbol
          @default_reduction = nil
        end
      end
    end
  end
end
