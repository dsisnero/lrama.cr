require "./reporter/conflicts"
require "./reporter/precedences"
require "./reporter/states"
require "./tracer/duration"

module Lrama
  class Reporter
    include Tracer::Duration

    def initialize(**options)
      @conflicts = Conflicts.new
      @precedences = Precedences.new
      @states = States.new(**options)
    end

    def report(io, states)
      report_duration(:report) do
        report_duration(:report_conflicts) { @conflicts.report(io, states) }
        report_duration(:report_precedences) { @precedences.report(io, states) }
        report_duration(:report_states) { @states.report(io, states, ielr: states.ielr_defined?) }
      end
    end
  end
end
