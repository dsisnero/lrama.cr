module Lrama
  class Counterexamples
    class Node(T)
      getter elem : T
      getter next_node : Node(T)?

      def self.to_a(node : Node(T))
        items = [] of T
        while node
          items << node.elem
          node = node.next_node
        end
        items
      end

      def initialize(@elem : T, @next_node : Node(T)?)
      end
    end
  end
end
