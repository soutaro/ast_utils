module ASTUtils
  class NodeSet
    class Item
      attr_reader :object

      def initialize(object)
        @object = object
      end

      def hash
        object.__id__
      end

      def eql?(other)
        other.is_a?(Item) && other.object.__id__ == object.__id__
      end

      def ==(other)
        eql?(other)
      end
    end

    attr_reader :set

    def initialize(objects = [])
      @set = Set.new(objects.map {|object| Item.new(object) })
    end

    def <<(node)
      set << Item.new(node)
    end

    def delete(node)
      set.delete Item.new(node)
    end

    def each(&block)
      set.map(&:object).each(&block)
    end

    def size
      set.size
    end

    include Enumerable
  end
end
