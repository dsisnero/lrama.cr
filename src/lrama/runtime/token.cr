module Lrama
  module Runtime
    alias Value = Int32 | Int64 | Float32 | Float64 | Bool | String | Char | Symbol | Slice(UInt8) | Nil

    struct Token
      getter sym : Int32
      getter value : Value
      getter location : Location?

      def initialize(@sym : Int32, @value : Value = nil, @location : Location? = nil)
      end
    end
  end
end
