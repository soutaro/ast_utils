require "test_helper"

class ScopeTest < Minitest::Test
  include TestHelper

  def parse(source)
    ASTUtils::Labeling.translate(node: Parser::Ruby25.parse(source))
  end

  def test_scope
    node = parse(<<-EOS)
class Foo
  def foo
    a = tap do |x|
      y = x
    end
  end
end
    EOS

    scope = ASTUtils::Scope.from(node: node)

    class_node = scope.root
    def_node = dig(scope.root, 2)
    block_node = dig(def_node, 2, 1)

    assert_equal 1, scope.children(class_node).size
    assert scope.children(class_node).any? {|n| n.equal?(def_node) }
    assert_empty scope.subs(class_node)

    assert scope.parent(def_node).equal?(class_node)
    assert_nil scope.sup(def_node)

    assert_empty scope.assignments(class_node)
    assert_empty scope.references(class_node)

    assert_equal 1, scope.children(def_node).size
    assert scope.children(def_node).any? {|n| n.equal?(block_node) }
    assert_equal 1, scope.subs(def_node).size
    assert scope.subs(def_node).any? {|n| n.equal?(block_node) }

    assert scope.parent(block_node).equal?(def_node)
    assert scope.sup(block_node).equal?(def_node)

    assert_equal 1, scope.assignments(def_node).size
    assert scope.assignments(def_node).any? {|assignment| assignment.node.type == :lvasgn && assignment.variable.name == :a }
    assert_empty scope.references(def_node)

    assert_empty scope.children(block_node)
    assert_empty scope.subs(block_node)

    assert_equal 2, scope.assignments(block_node).size
    assert scope.assignments(block_node).any? {|assignment| assignment.node.type == :procarg0 && assignment.variable.name == :x }
    assert scope.assignments(block_node).any? {|assignment| assignment.node.type == :lvasgn && assignment.variable.name == :y }
    assert 1, scope.references(block_node).size
    assert scope.references(block_node).any? {|node| node.type == :lvar && node.children[0].name == :x }

    assert scope.parent(block_node).equal?(def_node)
    assert scope.sup(block_node).equal?(def_node)
  end

  def test_assignments1
    node = parse(<<-EOS)
a = foo
b, *c = a
    EOS

    scope = ASTUtils::Scope.from(node: node)

    a = dig(node, 0)
    b = dig(node, 1, 0, 0)
    c = dig(node, 1, 0, 1, 0)

    assert_equal 3, scope.assignments(node).size
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(a) && assignment.variable.name == :a }
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(b) && assignment.variable.name == :b }
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(c) && assignment.variable.name == :c }
  end

  def test_assignments_def
    node = parse(<<-EOS)
def foo(x0, x1 = 1, *x2, x3:, x4: 2, **x5, &x6)
end
    EOS

    scope = ASTUtils::Scope.from(node: node)
    assignments = scope.assignments(node)

    x0 = dig(node, 1, 0)
    x1 = dig(node, 1, 1)
    x2 = dig(node, 1, 2)
    x3 = dig(node, 1, 3)
    x4 = dig(node, 1, 4)
    x5 = dig(node, 1, 5)
    x6 = dig(node, 1, 6)

    assert_equal 7, assignments.size
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(x0) && assignment.variable.name == :x0 }
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(x1) && assignment.variable.name == :x1 }
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(x2) && assignment.variable.name == :x2 }
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(x3) && assignment.variable.name == :x3 }
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(x4) && assignment.variable.name == :x4 }
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(x5) && assignment.variable.name == :x5 }
    assert scope.assignments(node).any? {|assignment| assignment.node.equal?(x6) && assignment.variable.name == :x6 }
  end

  def test_assignments_block
    node = parse(<<-EOS)
bar do |x0, x1=1, *x2, x3:, x4: 2, **x5, &x6|
end
    EOS

    scope = ASTUtils::Scope.from(node: node)
    assignments = scope.assignments(node)

    x0 = dig(node, 1, 0)
    x1 = dig(node, 1, 1)
    x2 = dig(node, 1, 2)
    x3 = dig(node, 1, 3)
    x4 = dig(node, 1, 4)
    x5 = dig(node, 1, 5)
    x6 = dig(node, 1, 6)

    assert_equal 7, assignments.size
    assert assignments.any? {|assignment| assignment.node.equal?(x0) && assignment.variable.name == :x0 }
    assert assignments.any? {|assignment| assignment.node.equal?(x1) && assignment.variable.name == :x1 }
    assert assignments.any? {|assignment| assignment.node.equal?(x2) && assignment.variable.name == :x2 }
    assert assignments.any? {|assignment| assignment.node.equal?(x3) && assignment.variable.name == :x3 }
    assert assignments.any? {|assignment| assignment.node.equal?(x4) && assignment.variable.name == :x4 }
    assert assignments.any? {|assignment| assignment.node.equal?(x5) && assignment.variable.name == :x5 }
    assert assignments.any? {|assignment| assignment.node.equal?(x6) && assignment.variable.name == :x6 }
  end

  def test_assignments_block2
    root = parse(<<-EOS)
f do |(a, (b, c))|
end
    EOS

    scope = ASTUtils::Scope.from(node: root)
    assignments = scope.assignments(root)

    a = dig(root, 1, 0, 0)
    b = dig(root, 1, 0, 1, 0)
    c = dig(root, 1, 0, 1, 1)

    assert_equal 3, assignments.size
    assert assignments.any? {|assignment| assignment.node.equal?(a) && assignment.variable.name == :a }
    assert assignments.any? {|assignment| assignment.node.equal?(b) && assignment.variable.name == :b }
    assert assignments.any? {|assignment| assignment.node.equal?(c) && assignment.variable.name == :c }
  end

  def test_assignment_block3
    root = parse(<<-EOS)
f do |a|
end
    EOS

    scope = ASTUtils::Scope.from(node: root)
    assignments = scope.assignments(root)

    a = dig(root, 1, 0)

    assert_equal 1, assignments.size
    assert assignments.any? {|assignment| assignment.node.equal?(a) && assignment.variable.name == :a }
  end

  def test_assignments_rescue
    node = parse(<<-EOS)
begin
  baz
rescue E => z1
  ()
rescue => z0
  ()
end
    EOS

    scope = ASTUtils::Scope.from(node: node)
    assignments = scope.assignments(node)

    z1 = dig(node, 0, 1, 1)
    z2 = dig(node, 0, 2, 1)

    assert_equal 2, assignments.size
    assert assignments.any? {|assignment| assignment.node.equal?(z1) && assignment.variable.name == :z1 }
    assert assignments.any? {|assignment| assignment.node.equal?(z2) && assignment.variable.name == :z0 }
  end

  def test_assignments_regexp
    root = parse(<<-EOS)
/(?<x>..)(?'y'..)/ =~ gets
    EOS

    scope = ASTUtils::Scope.from(node: root)
    assignments = scope.assignments(root)

    assert_equal 2, assignments.size
    assert assignments.any? {|assignment| assignment.node.equal?(root) && assignment.variable.name == :x }
    assert assignments.any? {|assignment| assignment.node.equal?(root) && assignment.variable.name == :y }
  end
end
