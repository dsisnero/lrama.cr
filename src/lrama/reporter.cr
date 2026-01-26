require "./reporter/conflicts"
require "./reporter/grammar"
require "./reporter/precedences"
require "./reporter/rules"
require "./reporter/states"
require "./reporter/terms"
require "./tracer/duration"

module Lrama
  class Reporter
    include Tracer::Duration

    def initialize(@options : Hash(Symbol, Bool) = {} of Symbol => Bool)
      @rules = Rules.new(@options[:rules]? || false)
      @terms = Terms.new(@options[:terms]? || false)
      @conflicts = Conflicts.new
      @precedences = Precedences.new
      @grammar = Grammar.new(@options[:grammar]? || false)
      @states = States.new(
        @options[:itemsets]? || false,
        @options[:lookaheads]? || false,
        @options[:solved]? || false,
        @options[:counterexamples]? || false,
        @options[:verbose]? || false
      )
    end

    def report(io, states)
      report_duration(:report) do
        report_duration(:report_rules) { @rules.report(io, states) }
        report_duration(:report_terms) { @terms.report(io, states) }
        report_duration(:report_conflicts) { @conflicts.report(io, states) }
        report_duration(:report_precedences) { @precedences.report(io, states) }
        report_duration(:report_grammar) { @grammar.report(io, states) }
        report_duration(:report_states) { @states.report(io, states, ielr: states.ielr_defined?) }
      end
    end
  end
end
