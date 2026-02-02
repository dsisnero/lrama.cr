module Lrama
  class Profiler
    def self.run(options : Hash(Symbol, Bool)?, io : IO, &)
      return yield if options.nil? || options.empty?

      report_call_stack(io) if options[:call_stack]?

      if options[:memory]?
        GC.collect
        before = GC.stats
        start = Time.monotonic
        result = yield
        GC.collect
        after = GC.stats
        elapsed = (Time.monotonic - start).total_seconds
        io.puts "profile.time total=#{format_seconds(elapsed)}"
        io.puts "profile.memory before=#{before}"
        io.puts "profile.memory after=#{after}"
        result
      else
        start = Time.monotonic
        result = yield
        elapsed = (Time.monotonic - start).total_seconds
        io.puts "profile.time total=#{format_seconds(elapsed)}"
        result
      end
    end

    private def self.report_call_stack(io : IO)
      io.puts "profile.call_stack note=use_external_profiler"
    end

    private def self.format_seconds(seconds : Float64)
      sprintf("%0.5fs", seconds)
    end
  end
end
