module ASTUtils
  module NodeHelper
    def each_child_node(node)
      if block_given?
        node.children.each do |child|
          if child.is_a?(AST::Node)
            yield child
          end
        end
      else
        enum_for :each_child_node, node
      end
    end

    # order preserved
    def map_child_node(node)
      if block_given?
        node.children.each.with_object([]) do |child, array|
          if child.is_a?(AST::Node)
            array << yield(child)
          else
            array << child
          end
        end
      else
        enum_for :map_child_node, node
      end
    end
  end
end
