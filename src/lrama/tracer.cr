require "./tracer/duration"

module Lrama
  class Tracer
    def initialize(@io : IO? = nil, @options : Hash(Symbol, Bool) = {} of Symbol => Bool)
      @time_enabled = @options[:time]? ? true : false
    end

    def trace(grammar : Grammar)
    end

    def trace_closure(state : State)
    end

    def trace_state(state : State)
    end

    def trace_state_list_append(state_count : Int32, state : State)
    end

    def enable_duration
      Duration.enable if @time_enabled
    end
  end
end
