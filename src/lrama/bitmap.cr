module Lrama
  module Bitmap
    alias Bitmap = Array(Int32)

    def self.from_integer(number : Int32)
      [number]
    end
  end
end
