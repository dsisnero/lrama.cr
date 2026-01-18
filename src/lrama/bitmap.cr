require "set"

module Lrama
  module Bitmap
    alias Bitmap = Set(Int32)

    def self.from_integer(number : Int32)
      Set{number}
    end

    def self.from_array(numbers : Array(Int32))
      numbers.to_set
    end

    def self.to_array(bitmap : Bitmap)
      bitmap.to_a
    end
  end
end
