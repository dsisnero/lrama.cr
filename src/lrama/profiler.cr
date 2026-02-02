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
        report_gc_stats(io, before, after)
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

    private def self.report_gc_stats(io : IO, before : GC::Stats, after : GC::Stats)
      report_stat(io, "bytes_since_gc", before.bytes_since_gc, after.bytes_since_gc)
      report_stat(io, "free_bytes", before.free_bytes, after.free_bytes)
      report_stat(io, "heap_size", before.heap_size, after.heap_size)
      report_stat(io, "total_bytes", before.total_bytes, after.total_bytes)
      report_stat(io, "unmapped_bytes", before.unmapped_bytes, after.unmapped_bytes)
    end

    private def self.report_stat(io : IO, name : String, before : Int64, after : Int64)
      delta = after - before
      io.puts "profile.memory.#{name} before=#{before} after=#{after} delta=#{delta}"
    end
  end
end
