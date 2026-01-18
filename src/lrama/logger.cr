module Lrama
  class Logger
    def initialize(@out : IO = STDERR)
    end

    def line_break
      @out << "\n"
    end

    def trace(message : String)
      @out << message << "\n"
    end

    def warn(message : String)
      @out << "warning: " << message << "\n"
    end

    def error(message : String)
      @out << "error: " << message << "\n"
    end
  end
end
