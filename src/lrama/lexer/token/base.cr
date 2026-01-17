module Lrama
  class Lexer
    module Token
      class Base
        getter s_value : String
        getter location : Location
        getter errors : Array(String)
        property alias_name : String?
        property? referred : Bool

        def initialize(@s_value : String, @location : Location, @alias_name : String? = nil)
          @errors = [] of String
          @referred = false
        end

        def to_s
          "value: `#{s_value}`, location: #{location}"
        end

        def referred_by?(string : String)
          s_value == string || alias_name == string
        end

        def ==(other : Base)
          self.class == other.class && s_value == other.s_value
        end

        def first_line
          location.first_line
        end

        def first_column
          location.first_column
        end

        def last_line
          location.last_line
        end

        def last_column
          location.last_column
        end

        def validate
          true
        end
      end
    end
  end
end
