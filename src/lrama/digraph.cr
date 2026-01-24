module Lrama
  class Digraph(TNode, TSet)
    def initialize(@nodes : Array(TNode), @relation : Hash(TNode, Array(TNode)), @base : Hash(TNode, TSet))
      @stack = [] of TNode
      @index = Hash(TNode, Int32).new(0)
      @result = {} of TNode => TSet
    end

    def compute
      @nodes.each do |node|
        next unless @index[node] == 0
        traverse(node)
      end
      @result
    end

    private def traverse(node : TNode)
      @stack << node
      depth = @stack.size
      @index[node] = depth
      @result[node] = @base[node]

      @relation[node]?.try do |neighbors|
        neighbors.each do |neighbor|
          traverse(neighbor) if @index[neighbor] == 0
          @index[node] = {@index[node], @index[neighbor]}.min
          @result[node] = @result[node] | @result[neighbor]
        end
      end

      return unless @index[node] == depth

      while item = @stack.pop?
        @index[item] = Int32::MAX
        break if item == node
        @result[item] = @result[node]
      end
    end
  end
end
