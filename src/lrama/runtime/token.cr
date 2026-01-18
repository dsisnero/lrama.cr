module Lrama
  module Runtime
    struct Token
      getter sym : Int32
      getter value : Object?
      getter location : Location?

      def initialize(@sym : Int32, @value : Object? = nil, @location : Location? = nil)
      end
    end
  end
end
