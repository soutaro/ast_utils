module ASTUtils
  class Scope
    class Assignment
      attr_reader :node, :variable

      def initialize(node:, variable:)
        @node = node
        @variable = variable
      end

      def hash
        node.__id__ ^ variable.hash
      end

      def eql?(other)
        other.is_a?(Assignment) && other.node.__id__ == node.__id__ && other.variable == variable
      end

      def ==(other)
        eql?(other)
      end
    end

    include NodeHelper

    attr_reader :root
    attr_reader :all_scopes
    attr_reader :child_scopes
    attr_reader :parent_scopes
    attr_reader :sub_scopes
    attr_reader :super_scopes
    attr_reader :assignment_nodes
    attr_reader :reference_nodes

    def initialize(root:)
      @root = root
      @all_scopes = NodeSet.new
      @child_scopes = {}
      @parent_scopes = {}
      @sub_scopes = {}
      @super_scopes = {}
      @assignment_nodes = {}
      @reference_nodes = {}
    end

    def children(scope)
      child_scopes[scope.__id__]
    end

    def parent(scope)
      parent_scopes[scope.__id__]
    end

    def subs(scope)
      sub_scopes[scope.__id__]
    end

    def sup(scope)
      super_scopes[scope.__id__]
    end

    def assignments(scope, include_subs: false)
      if include_subs
        subs(scope).inject(assignment_nodes[scope.__id__]) {|assignments, scope_|
          assignments + assignments(scope_, include_subst: true)
        }
      else
        assignment_nodes[scope.__id__]
      end
    end

    def references(scope, include_subs: false)
      if include_subs
        subs(scope).inject(reference_nodes[scope.__id__]) {|references, scope_|
          references + references(scope_, include_subs: true)
        }
      else
        reference_nodes[scope.__id__]
      end

    end

    def each(&block)
      all_scopes.each(&block)
    end

    def construct
      if Scope.scope_node?(root)
        child_scope!(root, nil)
      else
        add_scope(root)
        construct_node(root, root)
      end
    end

    def add_scope(scope)
      all_scopes << scope
      child_scopes[scope.__id__] = NodeSet.new
      sub_scopes[scope.__id__] = NodeSet.new
      assignment_nodes[scope.__id__] = Set.new
      reference_nodes[scope.__id__] = Set.new
    end

    def child_scope!(scope, parent_scope)
      add_scope(scope)

      if parent_scope
        parent_scopes[scope.__id__] = parent_scope
        child_scopes[parent_scope.__id__] << scope
      end

      each_child_node(scope) do |child|
        construct_node(child, scope)
      end
    end

    def nested_scope!(scope, super_scope)
      add_scope(scope)

      if super_scope
        parent_scopes[scope.__id__] = super_scope
        child_scopes[super_scope.__id__] << scope
        super_scopes[scope.__id__] = super_scope
        sub_scopes[super_scope.__id__] << scope
      end

      each_child_node(scope) do |child|
        construct_node(child, scope)
      end
    end

    def construct_node(node, current_scope)
      case node.type
      when :class, :module, :def
        child_scope!(node, current_scope)
      when :block
        nested_scope!(node, current_scope)
      when :lvar
        reference_nodes[current_scope.__id__] << node
      when :lvasgn, :arg, :optarg, :restarg, :kwarg, :kwoptarg, :kwrestarg, :blockarg
        assignment_nodes[current_scope.__id__] << Assignment.new(node: node, variable: node.children[0])
        construct_children(node, current_scope)
      when :procarg0
        case node.children[0]
        when AST::Node
          construct_children(node, current_scope)
        else
          assignment_nodes[current_scope.__id__] << Assignment.new(node: node, variable: node.children[0])
          construct_children(node, current_scope)
        end
      when :match_with_lvasgn
        node.children[2].each do |var|
          assignment_nodes[current_scope.__id__] << Assignment.new(node: node, variable: var)
        end

        construct_children(node, current_scope)
      else
        construct_children(node, current_scope)
      end
    end

    def construct_children(node, current_scope)
      each_child_node(node) do |child|
        construct_node(child, current_scope)
      end
    end

    def valid_scope!(node)
      unless root.equal?(node) || Scope.scope_node?(node)
        raise "Invalid scope node given: #{node}"
      end
    end

    def self.from(node:)
      new(root: node).tap(&:construct)
    end

    def self.scope_node?(node)
      case node.type
      when :class, :module, :def, :block
        true
      else
        false
      end
    end
  end
end
