module Lrama
  class Tracer
    module Duration
      @@report_duration_enabled = false

      def self.enable
        @@report_duration_enabled = true
      end

      def self.enabled?
        @@report_duration_enabled
      end

      def report_duration(message, &)
        start_time = Time.instant
        result = yield
        end_time = Time.instant

        if Duration.enabled?
          elapsed = (end_time - start_time).total_seconds
          STDERR.puts "#{message} #{sprintf("%10.5f", elapsed)} s"
        end

        result
      end
    end
  end
end
