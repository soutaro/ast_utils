require "test_helper"

class RelationshipTest < Minitest::Test
  include ASTUtils::NodeHelper
  include TestHelper

  Relationship = ASTUtils::Relationship
  Enter = Relationship::Enter
  Leave = Relationship::Leave
  Return = Relationship::Return

  def parse(source)
    Parser::Ruby27.parse(source)
  end

  def test_begin
    node = parse(<<EOF)
true
false
EOF
    rel = Relationship.new(node: node)
    rel.compute_node()

    assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
    assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)
  end

  def test_begin_return
    node = parse(<<EOF)
true
return
false
EOF
    rel = Relationship.new(node: node)
    rel.compute_node()

    assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
    assert_operator rel.next_vertexes[Enter.new(dig(node, 1))], :include?, Return.new
    refute_node_relation rel, from_enter: dig(node, 1), to_enter: dig(node, 2)
  end

  def test_if
    node = parse(<<EOF)
if f()
  g()
else
  h()
end
EOF
    rel = Relationship.new(node: node)
    rel.compute_node()

    assert_equal Set[Relationship::Enter.new(dig(node, 0))],
                 rel.next_vertexes[Relationship::Enter.new(node)]
    assert_equal Set[
                   Relationship::Enter.new(dig(node, 1)),
                   Relationship::Enter.new(dig(node, 2)),
                 ],
                 rel.next_vertexes[Relationship::Leave.new(dig(node, 0))]
    assert_equal Set[Relationship::Leave.new(node)],
                 rel.next_vertexes[Relationship::Leave.new(dig(node, 1))]
    assert_equal Set[Relationship::Leave.new(node)],
                 rel.next_vertexes[Relationship::Leave.new(dig(node, 2))]
  end

  def test_assign
    node = parse(<<EOF)
a = 1
EOF
    rel = Relationship.new(node: node)
    rel.compute_node()

    assert_equal Set[Relationship::Enter.new(dig(node, 1))],
                 rel.next_vertexes[Relationship::Enter.new(node)]
    assert_equal Set[Relationship::Leave.new(node)],
                 rel.next_vertexes[Relationship::Leave.new(dig(node, 1))]
  end

  def assert_node_relation(rel, from_enter: nil, from_leave: nil, to_enter: nil, to_leave: nil)
    from = case
           when from_enter
             Relationship::Enter.new(from_enter)
           when from_leave
             Relationship::Leave.new(from_leave)
           end

    to = case
         when to_enter
           Relationship::Enter.new(to_enter)
         when to_leave
           Relationship::Leave.new(to_leave)
         end

    assert_operator rel.next_vertexes[from], :include?, to
    assert_operator rel.prev_vertexes[to], :include?, from
  end

  def refute_node_relation(rel, from_enter: nil, from_leave: nil, to_enter: nil, to_leave: nil)
    from = case
           when from_enter
             Relationship::Enter.new(from_enter)
           when from_leave
             Relationship::Leave.new(from_leave)
           end

    to = case
         when to_enter
           Relationship::Enter.new(to_enter)
         when to_leave
           Relationship::Leave.new(to_leave)
         end

    refute_operator rel.next_vertexes[from] || [], :include?, to
    refute_operator rel.prev_vertexes[to] || [], :include?, from
  end

  def test_send
    node = parse(<<EOF)
foo.bar(a, *b, c, d: d, **e, &f)
EOF
    rel = Relationship.new(node: node)
    rel.compute_node()

    assert_node_relation rel, from_enter: node, to_enter: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 2)
    assert_node_relation rel, from_leave: dig(node, 2), to_enter: dig(node, 3)
    assert_node_relation rel, from_leave: dig(node, 3), to_enter: dig(node, 4)
    assert_node_relation rel, from_leave: dig(node, 4), to_enter: dig(node, 5)
    assert_node_relation rel, from_leave: dig(node, 6), to_leave: dig(node)
  end

  def test_array
    node = parse(<<EOF)
[1, *foo, 3, *bar]
EOF
    rel = Relationship.new(node: node)
    rel.compute_node()

    assert_node_relation rel, from_enter: node, to_enter: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
    assert_node_relation rel, from_leave: dig(node, 1), to_enter: dig(node, 2)
    assert_node_relation rel, from_leave: dig(node, 2), to_enter: dig(node, 3)
    assert_node_relation rel, from_leave: dig(node, 3), to_leave: dig(node)
  end

  def test_hash
    node = parse(<<EOF)
{ hello: world, "hello" => "world" }
EOF
    rel = Relationship.new(node: node)
    rel.compute_node()

    assert_node_relation rel, from_enter: node, to_enter: dig(node, 0)
    assert_node_relation rel, from_enter: dig(node, 0), to_enter: dig(node, 0, 0)
    assert_node_relation rel, from_leave: dig(node, 0, 0), to_enter: dig(node, 0, 1)
    assert_node_relation rel, from_leave: dig(node, 0, 1), to_leave: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
    assert_node_relation rel, from_enter: dig(node, 1), to_enter: dig(node, 1, 0)
    assert_node_relation rel, from_leave: dig(node, 1, 0), to_enter: dig(node, 1, 1)
    assert_node_relation rel, from_leave: dig(node, 1, 1), to_leave: dig(node, 1)
    assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)
  end

  def test_block
    node = parse(<<EOF)
[1,2,3].each do |x, y=2|
  x + 1
end
EOF
    rel = Relationship.new(node: node)
    rel.compute_node()

    send, args, block = node.children

    assert_node_relation rel, from_enter: node, to_enter: dig(send, 0)

    assert_node_relation rel, from_leave: dig(send, 0), to_leave: node
    assert_node_relation rel, from_leave: dig(send, 0), to_enter: args

    assert_node_relation rel, from_leave: args, to_enter: block

    assert_node_relation rel, from_leave: block, to_leave: node
    assert_node_relation rel, from_leave: block, to_enter: args
  end

  def test_and_or
    node = parse(<<EOF)
a = f && g
b = f || g
f && g && h
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    node.children[0].tap do |assign|
      assert_node_relation rel, from_enter: dig(assign, 1), to_enter: dig(assign, 1, 0)

      assert_node_relation rel, from_leave: dig(assign, 1, 0), to_enter: dig(assign, 1, 1)
      assert_node_relation rel, from_leave: dig(assign, 1, 0), to_leave: dig(assign, 1)

      assert_node_relation rel, from_leave: dig(assign, 1, 1), to_leave: dig(assign, 1)
    end

    node.children[1].tap do |assign|
      assert_node_relation rel, from_enter: dig(assign, 1), to_enter: dig(assign, 1, 0)

      assert_node_relation rel, from_leave: dig(assign, 1, 0), to_enter: dig(assign, 1, 1)
      assert_node_relation rel, from_leave: dig(assign, 1, 0), to_leave: dig(assign, 1)

      assert_node_relation rel, from_leave: dig(assign, 1, 1), to_leave: dig(assign, 1)
    end
  end

  def test_csend
    node = parse(<<EOF)
f&.g(h)
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: node, to_enter: dig(node, 0)

    assert_node_relation rel, from_leave: dig(node, 0), to_leave: node
    assert_node_relation rel, from_leave: node.children[0], to_enter: node.children[2]

    assert_node_relation rel, from_leave: node.children[2], to_leave: node
  end

  def test_while
    node = parse(<<EOF)
while f()
  g()
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: node, to_enter: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
    assert_node_relation rel, from_leave: dig(node, 1), to_enter: dig(node, 0)

    assert_node_relation rel, from_leave: dig(node, 0), to_leave: dig(node)
  end

  def test_while_empty
    node = parse(<<EOF)
while f()
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: node, to_enter: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 0)

    assert_node_relation rel, from_leave: dig(node, 0), to_leave: dig(node)
  end

  def test_jump
    node = parse(<<EOF)
f { break }
f { break 3,4,5 }
f { next }
f { next 1, 2 }
f { redo }
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: dig(node, 0, 2), to_leave: dig(node, 0)

    assert_node_relation rel, from_enter: dig(node, 1, 2), to_enter: dig(node, 1, 2, 0)
    assert_node_relation rel, from_leave: dig(node, 1, 2, 0), to_enter: dig(node, 1, 2, 1)
    assert_node_relation rel, from_leave: dig(node, 1, 2, 1), to_enter: dig(node, 1, 2, 2)
    assert_node_relation rel, from_leave: dig(node, 1, 2, 2), to_leave: dig(node, 1)

    assert_node_relation rel, from_enter: dig(node, 2, 2), to_leave: dig(node, 2, 2)

    assert_node_relation rel, from_enter: dig(node, 3, 2), to_enter: dig(node, 3, 2, 0)
    assert_node_relation rel, from_leave: dig(node, 3, 2, 0), to_enter: dig(node, 3, 2, 1)
    assert_node_relation rel, from_leave: dig(node, 3, 2, 1), to_leave: dig(node, 3, 2)

    assert_node_relation rel, from_enter: dig(node, 4, 2), to_enter: dig(node, 4, 2)
  end

  def test_return
    node = parse(<<EOF)
return 2
x = 1
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: dig(node, 0), to_enter: dig(node, 0, 0)
    assert_operator rel.next_vertexes[Relationship::Leave.new(dig(node, 0, 0))], :include?, Relationship::Return.new

    refute_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
  end

  def test_for
    node = parse(<<EOF)
for x in [1,2,3]
  puts x
end

for x in foo
  break
end

for x in foo
  next
end

for x in foo
  redo
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |loop|
      assert_node_relation rel, from_enter: dig(loop), to_enter: dig(loop, 1)
      assert_node_relation rel, from_leave: dig(loop, 1), to_enter: dig(loop, 0)
      assert_node_relation rel, from_leave: dig(loop, 0), to_enter: dig(loop, 2)
      assert_node_relation rel, from_leave: dig(loop, 2), to_enter: dig(loop, 0)

      assert_node_relation rel, from_leave: dig(loop, 2), to_leave: dig(loop)
    end

    dig(node, 1).tap do |loop|
      assert_node_relation rel, from_enter: dig(loop, 2), to_leave: dig(loop)
    end

    dig(node, 2).tap do |loop|
      assert_node_relation rel, from_enter: dig(loop, 2), to_leave: dig(loop, 2)
    end

    dig(node, 3).tap do |loop|
      assert_node_relation rel, from_enter: dig(loop, 2), to_enter: dig(loop, 2)
    end
  end

  def test_def
    node = parse(<<EOF)
def hello; end
def self.hello; end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |defn|
      assert_node_relation rel, from_enter: defn, to_leave: defn
    end

    dig(node, 1).tap do |defn|
      assert_node_relation rel, from_enter: dig(defn), to_enter: dig(defn, 0)
      assert_node_relation rel, from_leave: dig(defn, 0), to_leave: dig(defn)
    end
  end

  def test_const
    node = parse(<<EOF)
C
C::D
::C
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |const|
      assert_node_relation rel, from_enter: const, to_leave: const
    end

    dig(node, 1).tap do |const|
      assert_node_relation rel, from_enter: const, to_enter: dig(const, 0)
      assert_node_relation rel, from_leave: dig(const, 0), to_leave: dig(const)
    end

    dig(node, 2).tap do |const|
      assert_node_relation rel, from_enter: const, to_enter: dig(const, 0)
      assert_node_relation rel, from_leave: dig(const, 0), to_leave: dig(const)
    end
  end

  def test_casgn
    node = parse(<<EOF)
C = 1
C::D = 2
::C = 3
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |const|
      assert_node_relation rel, from_enter: dig(const), to_enter: dig(const, 2)
      assert_node_relation rel, from_leave: dig(const, 2), to_leave: dig(const)
    end

    dig(node, 1).tap do |const|
      assert_node_relation rel, from_enter: const, to_enter: dig(const, 0)
      assert_node_relation rel, from_leave: dig(const, 0), to_enter: dig(const, 2)
      assert_node_relation rel, from_leave: dig(const, 2), to_leave: dig(const)
    end

    dig(node, 2).tap do |const|
      assert_node_relation rel, from_enter: const, to_enter: dig(const, 0)
      assert_node_relation rel, from_leave: dig(const, 0), to_enter: dig(const, 2)
      assert_node_relation rel, from_leave: dig(const, 2), to_leave: dig(const)
    end
  end

  def test_class
    node = parse(<<EOF)
class Hello
end

class Object::World < Hello
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |klass|
      assert_node_relation rel, from_enter: klass, to_leave: klass
    end

    dig(node, 1).tap do |klass|
      assert_node_relation rel, from_enter: klass, to_enter: dig(klass, 0, 0)
      assert_node_relation rel, from_leave: dig(klass, 0, 0), to_enter: dig(klass, 1)
      assert_node_relation rel, from_leave: dig(klass, 1), to_leave: dig(klass)
    end
  end

  def test_module
    node = parse(<<EOF)
module Hello
end

module Object::World
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |mod|
      assert_node_relation rel, from_enter: mod, to_leave: mod
    end

    dig(node, 1).tap do |mod|
      assert_node_relation rel, from_enter: mod, to_enter: dig(mod, 0, 0)
      assert_node_relation rel, from_leave: dig(mod, 0, 0), to_leave: dig(mod)
    end
  end

  def test_case
    node = parse(<<EOF)
case f()
when A
  # nop
when B, C
  g()
end

case
when f(), g()
  h()
else
  h()
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0)
      assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1, 0)

      assert_node_relation rel, from_leave: dig(node, 1, 0), to_enter: dig(node, 2, 0)
      assert_node_relation rel, from_leave: dig(node, 2, 0), to_enter: dig(node, 2, 1)
      assert_node_relation rel, from_leave: dig(node, 2, 0), to_leave: dig(node)

      assert_node_relation rel, from_leave: dig(node, 2, 1), to_enter: dig(node, 2, 2)
      assert_node_relation rel, from_leave: dig(node, 2, 1), to_leave: dig(node)

      assert_node_relation rel, from_leave: dig(node, 2, 2), to_leave: dig(node)
    end

    dig(node, 1).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 1, 0)

      assert_node_relation rel, from_leave: dig(node, 1, 0), to_enter: dig(node, 1, 1)
      assert_node_relation rel, from_leave: dig(node, 1, 0), to_enter: dig(node, 1, 2)
      assert_node_relation rel, from_leave: dig(node, 1, 0), to_leave: dig(node)

      assert_node_relation rel, from_leave: dig(node, 1, 0), to_enter: dig(node, 1, 1)

      assert_node_relation rel, from_leave: dig(node, 1, 1), to_enter: dig(node, 1, 2)
      assert_node_relation rel, from_leave: dig(node, 1, 1), to_enter: dig(node, 2)
      assert_node_relation rel, from_leave: dig(node, 1, 1), to_leave: dig(node)

      assert_node_relation rel, from_leave: dig(node, 1, 2), to_leave: dig(node)

      assert_node_relation rel, from_leave: dig(node, 2), to_leave: dig(node)
    end
  end

  def test_begin_rescue
    node = parse(<<EOF)
begin
  foo()
rescue
  bar()
rescue A => e
  bar()
else
  baz()
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0)
      refute_node_relation rel, from_leave: dig(node), to_enter: dig(node, 3)

      assert_node_relation rel, from_enter: dig(node, 0), to_enter: dig(node, 1)
      assert_node_relation rel, from_enter: dig(node, 0), to_enter: dig(node, 2)

      assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
      assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 2)
      assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 3)

      assert_node_relation rel, from_enter: dig(node, 1), to_enter: dig(node, 1, 2)
      assert_node_relation rel, from_leave: dig(node, 1, 2), to_leave: dig(node, 1)
      assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)

      assert_node_relation rel, from_enter: dig(node, 2), to_enter: dig(node, 2, 0)

      assert_node_relation rel, from_leave: dig(node, 2, 0), to_enter: dig(node, 2, 1)
      assert_node_relation rel, from_leave: dig(node, 2, 0), to_leave: dig(node, 2)

      assert_node_relation rel, from_leave: dig(node, 2, 1), to_enter: dig(node, 2, 2)
      assert_node_relation rel, from_leave: dig(node, 2, 2), to_leave: dig(node, 2)

      assert_node_relation rel, from_leave: dig(node, 2), to_leave: dig(node)
    end
  end

  def test_ensure
    node = parse(<<EOF)
begin
  foo ()
ensure
  bar()
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0)

      assert_node_relation rel, from_enter: dig(node, 0), to_enter: dig(node, 1)
      assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)

      assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)
    end
  end

  def test_literals
    node = parse(<<'EOF')
"#{hello}#{world}"
/foo#{bar}#{baz}/
:"#{hogehoge}#{hugahuga}"
EOF

    rel = Relationship.new(node: node)
    rel.compute_node
  end

  def test_def_body
    node = parse(<<'EOF')
def self.hello(a, b=3, *c, d: :foo, e:, **f, &g)
  yield
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_def

    assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 2)
    assert_node_relation rel, from_leave: dig(node, 2), to_enter: dig(node, 3)
    assert_operator rel.next_vertexes[Relationship::Leave.new(dig(node, 3))],
                    :include?, Relationship::Return.new
  end

  def test_alias
    node = parse(<<'EOF')
alias foo bar
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: node, to_leave: node
  end

  def test_masgn
    node = parse(<<'EOF')
a, *b, c = [foo, *bar]
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 1)
    assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)
  end

  def test_regopt
    node = parse(<<'EOF')
/\(\?(\<([\w_]+)\>)|(\'([\w_]+)\')/
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
    assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)
  end

  def test_op_asgn
    node = parse(<<'EOF')
self[3] += 2
foo&.bar += 1
$counter += 1
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0, 0)
      assert_node_relation rel, from_leave: dig(node, 0, 0), to_enter: dig(node, 0, 2)
      assert_node_relation rel, from_leave: dig(node, 0, 2), to_enter: dig(node, 2)
      assert_node_relation rel, from_leave: dig(node, 2), to_leave: dig(node)
    end

    dig(node, 1).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0, 0)
      assert_node_relation rel, from_leave: dig(node, 0, 0), to_enter: dig(node, 2)
      assert_node_relation rel, from_leave: dig(node, 0, 0), to_leave: dig(node)
      assert_node_relation rel, from_leave: dig(node, 2), to_leave: dig(node)
    end

    dig(node, 2).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 2)
      assert_node_relation rel, from_leave: dig(node, 2), to_leave: dig(node)
    end
  end

  def test_or_and_asgn
    node = parse(<<'EOF')
foo[1] ||= true
self&.flag ||= true
hello &&= world
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    dig(node, 0).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0, 0)
      assert_node_relation rel, from_leave: dig(node, 0, 0), to_enter: dig(node, 0, 2)
      assert_node_relation rel, from_leave: dig(node, 0, 2), to_enter: dig(node, 1)
      assert_node_relation rel, from_leave: dig(node, 0, 2), to_leave: dig(node)
      assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)
    end

    dig(node, 1).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0, 0)
      assert_node_relation rel, from_leave: dig(node, 0, 0), to_enter: dig(node, 1)
      assert_node_relation rel, from_leave: dig(node, 0, 0), to_leave: dig(node)
      assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)
    end

    dig(node, 2).tap do |node|
      assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 1)
      assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)
      assert_node_relation rel, from_enter: dig(node), to_leave: dig(node)
    end
  end

  def test_sclass
    node = parse(<<'EOF')
class <<self
  defined? self
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
    assert_node_relation rel, from_leave: dig(node, 1), to_leave: dig(node)
  end

  def test_retry
    node = parse(<<'EOF')
begin
  foo()
rescue
  retry
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel,
                         from_enter: dig(node, 0, 1, 2),
                         to_enter: dig(node, 0, 1, 2)
  end

  def test_while_post
    node = parse(<<'EOF')
begin
  foo
end while bar
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    assert_node_relation rel, from_enter: dig(node), to_enter: dig(node, 1)
    assert_node_relation rel, from_leave: dig(node, 1), to_enter: dig(node, 0)
    assert_node_relation rel, from_leave: dig(node, 0), to_enter: dig(node, 1)
    assert_node_relation rel, from_leave: dig(node, 0), to_leave: dig(node)
  end

  def test_match_with_lvasgn
    node = parse(<<'EOF')
/\A[\-\+]?[\d.]+\Z/ =~ value
EOF

    rel = Relationship.new(node: node)
    rel.compute_node
  end

  def test_begin_end_less_range
    node = parse(<<'EOF')
a..
...b
EOF

    rel = Relationship.new(node: node)
    rel.compute_node
  end

  def test_cvar
    node = parse(<<'EOF')
module Foo
  @@x = 10
  @@x += 1
  @@x
end
EOF

    rel = Relationship.new(node: node)
    rel.compute_node
  end

  def test_reachables
    node = parse(<<EOF)
foo()

while f()
  g()
end

bar()
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    rel.reachable_vertexes_from(Enter.new(dig(node, 2))).tap do |set|
      assert_equal Set[
                     Leave.new(dig(node, 2)),
                     Leave.new(dig(node))
                   ],
                   set
    end

    rel.reachable_vertexes_from(Enter.new(dig(node, 1, 1))).tap do |set|
      assert_equal Set[
                     Enter.new(dig(node, 1, 1)),
                     Leave.new(dig(node, 1, 1)),
                     Enter.new(dig(node, 1, 0)),
                     Leave.new(dig(node, 1, 0)),
                     Leave.new(dig(node, 1)),
                     Enter.new(dig(node, 2)),
                     Leave.new(dig(node, 2)),
                     Leave.new(dig(node)),
                   ],
                   set
    end
  end

  def test_reachings
    node = parse(<<EOF)
foo()

while f()
  g()
end

bar()
EOF

    rel = Relationship.new(node: node)
    rel.compute_node

    rel.reaching_vertexes_to(Leave.new(dig(node, 0))).tap do |set|
      assert_equal Set[
                     Enter.new(dig(node, 0)),
                     Enter.new(dig(node))
                   ],
                   set
    end

    rel.reaching_vertexes_to(Enter.new(dig(node, 1, 1))).tap do |set|
      assert_equal Set[
                     Enter.new(dig(node, 1, 1)),
                     Leave.new(dig(node, 1, 1)),
                     Enter.new(dig(node, 1, 0)),
                     Leave.new(dig(node, 1, 0)),
                     Enter.new(dig(node, 1)),
                     Enter.new(dig(node, 0)),
                     Leave.new(dig(node, 0)),
                     Enter.new(dig(node)),
                   ],
                   set
    end
  end
end
