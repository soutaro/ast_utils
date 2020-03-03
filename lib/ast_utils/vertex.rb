module ASTUtils
  module Vertex
    class Base
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def hash
        self.class.hash ^ node.object_id
      end

      def ==(other)
        other.class == self.class && other.node.equal?(node)
      end

      alias eql? ==

      def inspect
        "#<#{self.class.name} node=#{node.type}(#{node.loc.line}:#{node.loc.column})>"
      end

      def to_s
        name = self.class.name.split(/::/).last
        loc = begin
                "#{node.loc.line}:#{node.loc.column}~#{node.loc.last_line}:#{node.loc.last_column}"
              rescue
                "***"
              end
        "#<#{name} node=#{node.type} (#{loc})>"
      end
    end

    class Enter < Base; end
    class Leave < Base; end
    class Return
      def hash
        self.class.hash
      end

      def ==(other)
        other.class == self.class
      end

      alias eql? ==

      def to_s
        "#<Return>"
      end
    end
  end
end
