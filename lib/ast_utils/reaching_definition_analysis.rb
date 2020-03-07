module ASTUtils
  class ReachingDefinitionAnalysis
    include Vertex

    attr_reader :rels
    attr_reader :fvs
    attr_reader :definitions

    def initialize(rels:, fvs:)
      @rels = rels
      @fvs = fvs

      @definitions = {}
    end

    # @type method: () -> Node
    def node
      rels.node
    end

    # @type method: (Node) -> Hash[Name, Set[Node | nil]]
    def at_enter(node)
      definitions[Enter.new(node)]
    end

    # @type method: (Node) -> Hash[Name, Set[Node | nil]]
    def at_leave(node)
      definitions[Leave.new(node)]
    end

    def analyze()
      definitions[Enter.new(node)] = fvs.each.with_object({}) do |fv, hash|
        hash[fv] = Set[nil].compare_by_identity
      end

      changed = rels.all_vertexes

      until changed.empty?
        v = changed.each.first
        changed.delete(v)

        prev = definitions[v] || empty_hash

        definitions[v] = empty_hash.merge((rels.prev_vertexes[v] || []).each.with_object({}) do |pv, hash|
          if (defs = definitions[pv])
            merge_defs(hash, defs)
          end
        end)

        if v.is_a?(Leave)
          case v.node.type
          when :lvasgn, :arg, :optarg, :restarg, :kwarg, :kwoptarg, :kwrestarg, :blockarg
            update_defs(v, v.node, v.node.children[0])
          end
        end

        unless prev == definitions[v]
          changed.merge(rels.next_vertexes[v]&.each || [])
        end
      end

      self
    end

    def empty_hash
      definitions[Enter.new(node)] = fvs.each.with_object({}) do |fv, hash|
        hash[fv] = Set[nil].compare_by_identity
      end
    end

    def update_defs(vertex, node, name)
      defs = (definitions[vertex] ||= empty_hash)
      defs[name] = Set[node].compare_by_identity
    end

    def merge_defs(d1, d2)
      d1.merge!(d2) do |_, s1, s2|
        s1 + s2
      end
    end
  end
end
