module Lrama
  module Runtime
    struct Location
      getter first_line : Int32
      getter first_column : Int32
      getter last_line : Int32
      getter last_column : Int32

      def initialize(
        @first_line : Int32,
        @first_column : Int32,
        @last_line : Int32,
        @last_column : Int32,
      )
      end

      def self.merge(first : Location?, last : Location?)
        return last unless first
        return first unless last

        Location.new(
          first_line: first.first_line,
          first_column: first.first_column,
          last_line: last.last_line,
          last_column: last.last_column
        )
      end
    end
  end
end
