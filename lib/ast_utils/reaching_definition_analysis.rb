module ASTUtils
  class ReachingDefinitionAnalysis
    include Vertex

    attr_reader :rels
    attr_reader :vars
    attr_reader :definitions

    def initialize(rels:, vars:)
      @rels = rels
      @vars = vars

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
      definitions[Enter.new(node)] = empty_hash

      changed = rels.all_vertexes

      count = 0

      until changed.empty?
        v = changed.each.first
        changed.delete(v)

        count += 1
        puts "    | #{count}th iteration, size = #{changed.size}, vertex=#{v}..."

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
          when :masgn
            vars = v.node.children[0].children.map do |n|
              case n.type
              when :lvasgn
                n.children[0]
              when :splat
                if n.children[0].type == :lvasgn
                  n.children[0].children[0]
                end
              end
            end.compact

            vars.each do |var|
              update_defs(v, v.node, var)
            end
          when :and_asgn, :or_asgn
            lhs = v.node.children[0]
            if lhs.type == :lvasgn
              var = lhs.children[0]
              update_defs(v, v.node, var, merge: true)
            end
          when :op_asgn
            var = v.node.children[0].children[0]
            update_defs(v, v.node, var)
          end
        end

        unless prev == definitions[v]
          changed.merge(rels.next_vertexes[v]&.each || [])
        end
      end

      self
    end

    def empty_hash
      definitions[Enter.new(node)] = vars.each.with_object({}) do |var, hash|
        hash[var] = Set[nil].compare_by_identity
      end
    end

    def update_defs(vertex, node, name, merge: false)
      if vars.include?(name)
        defs = definitions[vertex] ||= empty_hash

        if merge
          defs[name].add(node)
        else
          defs[name] = Set[node].compare_by_identity
        end
      else
        raise "Unknown variable name: #{name}"
      end
    end

    def merge_defs(d1, d2)
      d1.merge!(d2) do |_, s1, s2|
        s1 + s2
      end
    end
  end
end
