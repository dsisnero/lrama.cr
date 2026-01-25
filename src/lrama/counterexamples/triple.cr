module Lrama
  class Counterexamples
    class Triple
      getter precise_lookahead_set : Bitmap::Bitmap

      def initialize(@state_item : StateItem, @precise_lookahead_set : Bitmap::Bitmap)
      end

      def l
        @precise_lookahead_set
      end

      def state
        @state_item.state
      end

      def s
        state
      end

      def item
        @state_item.item
      end

      def itm
        item
      end

      def state_item
        @state_item
      end

      def inspect
        bits = Bitmap.to_array(l).join(",")
        "#{state.inspect}. #{item.display_name}. {#{bits}}"
      end

      def to_s
        inspect
      end
    end
  end
end
