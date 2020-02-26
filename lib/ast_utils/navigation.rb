module ASTUtils
  class Navigation
    include NodeHelper

    attr_reader :nodes
    attr_reader :parents
    attr_reader :root

    def initialize(node:)
      @root = node
      @nodes = Set[].compare_by_identity
      @parents = {}.compare_by_identity
    end

    def construct
      set_parent(root)
    end

    def set_parent(node)
      nodes << node

      each_child_node(node) do |child|
        parents[child] = node
        set_parent(child)
      end
    end

    def parent(node)
      parents[node]
    end

    def self.from(node:)
      new(node: node).tap {|nav| nav.construct }
    end
  end
end
