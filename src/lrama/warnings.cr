require "./warnings/conflicts"
require "./warnings/implicit_empty"
require "./warnings/name_conflicts"
require "./warnings/redefined_rules"
require "./warnings/required"
require "./warnings/useless_precedence"

module Lrama
  class Warnings
    def initialize(logger : Logger, warnings : Bool)
      @conflicts = Conflicts.new(logger, warnings)
      @implicit_empty = ImplicitEmpty.new(logger, warnings)
      @name_conflicts = NameConflicts.new(logger, warnings)
      @redefined_rules = RedefinedRules.new(logger, warnings)
      @required = Required.new(logger, warnings)
      @useless_precedence = UselessPrecedence.new(logger, warnings)
    end

    def warn(grammar : Grammar, states : States)
      @conflicts.warn(states)
      @implicit_empty.warn(grammar)
      @name_conflicts.warn(grammar)
      @redefined_rules.warn(grammar)
      @required.warn(grammar)
      @useless_precedence.warn(grammar, states)
    end
  end
end
