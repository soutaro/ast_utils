module ASTUtils
  class Relationship
    class Vertex
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

    class Enter < Vertex; end
    class Leave < Vertex; end
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

    class Logic
      attr_reader :operator
      attr_reader :values

      def initialize(operator:)
        @operator = operator
        @values = []
      end

      def operand
        values << yield
      end

      def test?
        case operator
        when :and
          values.all?(&:itself)
        when :or
          values.any?(&:itself)
        end
      end

      def self.and
        new(operator: :and)
      end

      def self.or
        new(operator: :or)
      end
    end

    attr_reader :node
    attr_reader :next_vertexes
    attr_reader :prev_vertexes
    attr_reader :on_def

    def initialize(node:, &block)
      @on_def = block

      @node = node
      @next_vertexes = {}
      @prev_vertexes = {}

      @break_stack = []
      @retry_stack = []
      @next_stack = []
      @redo_stack = []

      @reachable_vertexes = {}
      @reaching_vertexes = {}
    end

    def push_jump(break_to: false, retry_to: false, next_to: false, redo_to: false)
      @break_stack.push break_to unless break_to == false
      @retry_stack.push retry_to unless retry_to == false
      @next_stack.push next_to unless next_to == false
      @redo_stack.push redo_to unless redo_to == false

      yield
    ensure
      @break_stack.pop unless break_to == false
      @retry_stack.pop unless retry_to == false
      @next_stack.pop unless next_to == false
      @redo_stack.pop unless redo_to == false
    end

    def break_to
      raise "Unexpected jump: break" if @break_stack.empty?
      @break_stack.last
    end

    def retry_to
      raise "Unexpected jump: retry" if @retry_stack.empty?
      @retry_stack.last
    end

    def next_to
      raise "Unexpected jump: next" if @next_stack.empty?
      @next_stack.last
    end

    def redo_to
      raise "Unexpected jump: redo" if @redo_stack.empty?
      @redo_stack.last
    end

    def compute_def
      case node.type
      when :def
        _, args, body = node.children
        connect_nodes from_enter: node, to_enter: args
        compute args

        if body
          connect_nodes from_leave: args, to_enter: body
          compute(body)
          connect from: Leave(body), to: Return.new
        else
          connect from: Leave(args), to: Return.new
        end

      when :defs
        _, _, args, body = node.children

        connect_nodes from_enter: node, to_enter: args
        compute args

        if body
          connect_nodes from_leave: args, to_enter: body
          compute(body)
          connect from: Leave(body), to: Return.new
        else
          connect from: Leave(args), to: Return.new
        end

      else
        raise "Unexpected def node: #{node.type} (#{node.loc.line}:#{node.loc.column})"
      end

      self
    end

    def compute_node
      compute(node)
      self
    end

    def reachable_vertexes_from(vertex)
      if (vs = @reachable_vertexes[vertex])
        vs
      else
        @reachable_vertexes[vertex] = Set[]

        nexts = next_vertexes[vertex] || []
        set = Set[].merge(nexts)
        nexts.each do |v|
          set.merge(reachable_vertexes_from(v))
        end

        @reachable_vertexes[vertex] = set
      end
    end

    def reaching_vertexes_to(vertex)
      if (vs = @reaching_vertexes[vertex])
        vs
      else
        @reaching_vertexes[vertex] = Set[]

        prevs = prev_vertexes[vertex] || []
        set = Set[].merge(prevs)
        prevs.each do |v|
          set.merge(reaching_vertexes_to(v))
        end

        @reaching_vertexes[vertex] = set
      end
    end

    # Returns true when there is a edge to Leave(node).
    # Returns false when there is no edge to Leave(node). (jump to outside.)
    def compute(node)
      case node.type
      when :begin
        connect_children(node, *node.children) or return

      when :if
        c, t, f = node.children

        connect(from: Enter.new(node), to: Enter.new(c))
        compute(c)

        logic = Logic.or

        if t
          logic.operand do
            connect(from: Leave.new(c), to: Enter.new(t))
            compute(t) or next
            connect(from: Leave.new(t), to: Leave.new(node))
          end
        end

        if f
          logic.operand do
            connect(from: Leave.new(c), to: Enter.new(f))
            compute(f) or next
            connect(from: Leave.new(f), to: Leave.new(node))
          end
        end

        return logic.test?

      when :case
        subject, *whens, els = node.children

        cursor = Enter(node)

        if subject
          connect from: cursor, to: Enter(subject)
          compute(subject)
          cursor = Leave(subject)
        end

        whens.each do |w|
          *conds, body = w.children
          conds.each do |c|
            connect from: cursor, to: Enter(c)
            compute(c)
            connect_nodes from_leave: c, to_enter: body if body
            connect_nodes from_leave: c, to_leave: node
            cursor = Leave(c)
          end

          if body
            compute(body)
            connect_nodes from_leave: body, to_leave: node
          end
        end

        if els
          connect from: cursor, to: Enter(els)
          compute(els)
          connect_nodes from_leave: els, to_leave: node
        end

      when :lvasgn, :ivasgn, :gvasgn, :cvasgn
        if (rhs = node.children[1])
          connect_nodes(from_enter: node, to_enter: rhs)
          compute(rhs)
          connect_nodes(from_leave: rhs, to_leave: node)
        else
          connect_nodes(from_enter: node, to_leave: node)
        end

      when :send, :csend
        last = compute_send(node)
        connect from: last, to: Leave(node)

      when :block
        send, args, body = node.children
        last = compute_send(send, from: Enter(node))
        connect from: last, to: Leave(node)
        connect from: last, to: Enter(args)
        compute(args)

        if body
          connect_nodes from_leave: args, to_enter: body
          push_jump break_to: Leave(node), next_to: Leave(body), redo_to: Enter(body) do
            compute body
          end
          connect_nodes from_leave: body, to_leave: node

          connect_nodes from_leave: body, to_enter: args
        else
          connect_nodes from_leave: args, to_leave: node
        end

      when :optarg, :kwoptarg
        connect_nodes from_enter: node, to_leave: node

        connect_nodes from_enter: node, to_enter: node.children[1]
        compute(node.children[1])
        connect_nodes from_leave: node.children[1], to_leave: node

      when :and, :or
        l, r = node.children

        connect_nodes from_enter: node, to_enter: l
        compute(l)
        connect_nodes from_leave: l, to_enter: r

        connect_nodes from_leave: l, to_leave: node
        compute(r)
        connect_nodes from_leave: r, to_leave: node

      when :for
        asgn, collection, body = node.children

        connect_nodes from_enter: node, to_enter: collection
        compute(collection)
        connect_nodes from_leave: collection, to_enter: asgn
        compute asgn

        if body
          connect_nodes from_leave: asgn, to_enter: body
          push_jump break_to: Leave(node), redo_to: Enter(body), next_to: Leave(body) do
            compute body
          end
          connect_nodes from_leave: body, to_leave: node
          connect_nodes from_leave: body, to_enter: asgn
        end

      when :while, :until
        subject, body = node.children

        connect_nodes from_enter: node, to_enter: subject
        compute(subject)

        if body
          push_jump break_to: Leave(node), redo_to: Enter(body), next_to: Leave(body) do
            compute body
          end
          connect_nodes from_leave: subject, to_enter: body
          connect_nodes from_leave: body, to_enter: subject
        else
          connect_nodes from_leave: subject, to_enter: subject
        end

        connect_nodes from_leave: subject, to_leave: node

      when :while_post
        subject, body = node.children

        connect_nodes from_enter: node, to_enter: body
        compute(body)
        connect_nodes from_leave: body, to_enter: subject
        compute(subject)
        connect_nodes from_leave: subject, to_enter: body
        connect_nodes from_leave: subject, to_leave: node

      when :array, :hash, :pair, :splat, :kwsplat, :block_pass,
        :args, :kwbegin, :yield, :super, :mlhs
        connect_children node, *node.children

      when :irange, :erange
        connect_children node, *node.children.compact

      when :break
        *values = node.children

        if values.empty?
          connect from: Enter(node), to: break_to
        else
          last = connect_seq(Enter(node), *values)
          connect from: last, to: break_to
        end

        return false

      when :next
        *values = node.children

        if values.empty?
          connect from: Enter(node), to: next_to
        else
          last = connect_seq(Enter(node), *values)
          connect from: last, to: next_to
        end

        return false

      when :return
        *values = node.children

        if values.empty?
          connect from: Enter(node), to: Return.new
        else
          last = connect_seq(Enter(node), *values)
          connect from: last, to: Return.new
        end

        return false

      when :redo
        connect from: Enter(node), to: redo_to

        return false

      when :def
        connect_nodes(from_enter: node, to_leave: node)

        on_def[node] if on_def

      when :defs
        obj = node.children[0]
        connect_nodes(from_enter: node, to_enter: obj)
        compute(obj)
        connect_nodes(from_leave: obj, to_leave: node)

        on_def[node] if on_def

      when :class
        name, sup, body = node.children

        cursor = Enter(node)

        if name.children[0]
          connect_nodes from_enter: node, to_enter: name.children[0]
          compute name.children[0]
          cursor = Leave(name.children[0])
        end

        if sup
          connect from: cursor, to: Enter(sup)
          compute sup
          cursor = Leave(sup)
        end

        if body
          connect from: cursor, to: Enter(body)
          compute body
          cursor = Leave(body)
        end

        connect from: cursor, to: Leave(node)

      when :module
        name, body = node.children

        cursor = Enter(node)

        if name.children[0]
          connect_nodes from_enter: node, to_enter: name.children[0]
          compute name.children[0]
          cursor = Leave(name.children[0])
        end

        if body
          connect from: cursor, to: Enter(body)
          compute body
          cursor = Leave(body)
        end

        connect from: cursor, to: Leave(node)

      when :const
        parent = node.children[0]

        if parent
          connect_nodes from_enter: node, to_enter: parent
          compute(parent)
          connect_nodes from_leave: parent, to_leave: node
        else
          connect_nodes from_enter: node, to_leave: node
        end

      when :casgn
        parent, _, value = node.children

        if parent
          connect_nodes from_enter: node, to_enter: parent
          compute(parent)
          connect_nodes from_leave: parent, to_enter: value
        else
          connect_nodes from_enter: node, to_enter: value
        end

        compute(value)
        connect_nodes from_leave: value, to_leave: node

      when :rescue
        body, *ress, els = node.children

        if body
          connect_nodes from_enter: node, to_enter: body
          compute(body)
        end

        ress.each do |resbody|
          connect_nodes from_enter: body, to_enter: resbody
          connect_nodes from_leave: body, to_enter: resbody
          compute(resbody)
          connect_nodes from_leave: resbody, to_leave: node
        end

        if els
          connect_nodes from_leave: body, to_enter: els
          compute(els)
          connect_nodes from_leave: els, to_leave: node
        else
          connect_nodes from_leave: body, to_leave: node
        end

      when :resbody
        exns, asgn, body = node.children

        cursor = Enter(node)

        if exns
          connect from: cursor, to: Enter(exns)
          compute exns
          connect_nodes from_leave: exns, to_leave: node
          cursor = Leave(exns)
        end

        if asgn
          connect from: cursor, to: Enter(asgn)
          compute asgn
          cursor = Leave(asgn)
        end

        if body
          connect from: cursor, to: Enter(body)
          push_jump retry_to: Enter(body) do
            compute body
          end
          cursor = Leave(body)
        end

        connect from: cursor, to: Leave(node)

      when :retry
        connect from: Enter(node), to: retry_to
        return false

      when :ensure
        subject, body = node.children

        if subject
          connect_nodes from_enter: node, to_enter: subject
          connect_nodes from_enter: subject, to_enter: body
          compute subject
          connect_nodes from_leave: subject, to_enter: body
        else
          connect_nodes from_enter: node, to_enter: body
        end

        compute body

        connect_nodes from_leave: body, to_leave: node

      when :masgn
        asgn, body = node.children

        connect_nodes(from_enter: node, to_enter: body)
        compute body
        connect_nodes(from_leave: body, to_leave: node)

      when :dstr, :regexp, :dsym, :match_with_lvasgn
        connect_children(node, *node.children)

      when :op_asgn
        lhs, _, rhs = node.children

        case lhs.type
        when :send, :csend
          receiver, _, *args = lhs.children

          connect_nodes from_enter: node, to_enter: receiver
          compute(receiver)
          cursor = args.inject(Leave(receiver)) do |cursor, arg|
            connect from: cursor, to: Enter(arg)
            compute arg
            Leave(arg)
          end

          connect from: cursor, to: Enter(rhs)
          compute(rhs)
          connect_nodes from_leave: rhs, to_leave: node

          if lhs.type == :csend
            connect_nodes from_leave: receiver, to_leave: node
          end

        when :lvasgn, :ivasgn, :gvasgn, :cvasgn
          connect_nodes from_enter: node, to_enter: rhs
          compute(rhs)
          connect_nodes from_leave: rhs, to_leave: node

        else
          STDERR.puts "Unexpected #{node.type} lhs: lhs=#{lhs.type} (#{node.loc.line}:#{node.loc.column})"
          connect_nodes from_enter: node, to_leave: node
        end

      when :or_asgn, :and_asgn
        lhs, rhs = node.children

        case lhs.type
        when :send, :csend
          receiver, _, *args = lhs.children

          connect_nodes from_enter: node, to_enter: receiver
          compute(receiver)
          cursor = args.inject(Leave(receiver)) do |cursor, arg|
            connect from: cursor, to: Enter(arg)
            compute arg
            Leave(arg)
          end

          connect from: cursor, to: Leave(node)

          connect from: cursor, to: Enter(rhs)
          compute(rhs)
          connect_nodes from_leave: rhs, to_leave: node

          if lhs.type == :csend
            connect_nodes from_leave: receiver, to_leave: node
          end

        when :lvasgn, :ivasgn, :gvasgn, :cvasgn
          connect_nodes from_enter: node, to_enter: rhs
          compute(rhs)
          connect_nodes from_leave: rhs, to_leave: node

          connect_nodes from_enter: node, to_leave: node

        else
          STDERR.puts "Unexpected #{node.type} lhs: lhs=#{lhs.type} (#{node.loc.line}:#{node.loc.column})"
          connect_nodes from_enter: node, to_leave: node
        end

      when :int, :true, :false, :sym, :str, :arg, :restarg, :kwarg, :kwrestarg, :blockarg, :lvar, :ivar, :self, :cbase,
        :procarg0, :nil, :alias, :regopt, :gvar, :float, :zsuper, :defined?, :cvar
        # value node
        connect_nodes(from_enter: node, to_leave: node)

      when :sclass
        this, body = node.children
        connect_nodes from_enter: node, to_enter: this
        compute this

        if body
          connect_nodes from_leave: this, to_enter: body
          compute body
          connect_nodes from_leave: body, to_leave: node
        else
          connect_nodes from_leave: this, to_leave: node
        end

      when :when
        raise "Unexpected node: #{node.type} (#{node.loc.line}:#{node.loc.column})"

      else
        STDERR.puts "Unexpected node: #{node.type} (#{node.loc.line}:#{node.loc.column})"
        connect(from: Enter(node), to: Leave(node))
      end

      true
    end

    def compute_send(send_node, from: Enter(send_node))
      receiver, _, *args = send_node.children

      if receiver
        connect from: from, to: Enter(receiver)
        compute(receiver)
        start = Leave(receiver)
      else
        start = from
      end

      if send_node.type == :csend
        connect from: start, to: Leave(send_node)
      end

      connect_seq(start, *args)
    end

    def connect_nodes(from_enter: nil, from_leave: nil, to_enter: nil, to_leave: nil)
      case
      when from_enter && to_enter
        connect(from: Enter(from_enter), to: Enter(to_enter))
      when from_enter && to_leave
        connect(from: Enter(from_enter), to: Leave(to_leave))
      when from_leave && to_enter
        connect(from: Leave(from_leave), to: Enter(to_enter))
      when from_leave && to_leave
        connect(from: Leave(from_leave), to: Leave(to_leave))
      end
    end

    def connect_seq(start_vertex, *nodes)
      nodes.inject(start_vertex) do |last, node|
        connect from: last, to: Enter(node)
        compute(node) or return
        Leave(node)
      end
    end

    def Enter(node)
      Enter.new(node)
    end

    def Leave(node)
      Leave.new(node)
    end

    def connect_children(parent, *children)
      last = connect_seq Enter(parent), *children

      if last
        connect from: last, to: Leave(parent)
      end
    end

    def connect(from:, to:)
      add(next_vertexes, from, to)
      add(prev_vertexes, to, from)
    end

    def add(hash, key, *values)
      unless hash.key?(key)
        hash[key] = Set.new
      end

      hash[key].merge(values)
    end

    def each_edge(&block)
      if block
        next_vertexes.each do |from, tos|
          tos.each do |to|
            yield [from, to]
          end
        end
      else
        enum_for :each_edge
      end
    end
  end
end
