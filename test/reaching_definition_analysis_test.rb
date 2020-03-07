require "test_helper"

class ReachingDefinitionAnalysisTest < Minitest::Test
  include ASTUtils::NodeHelper
  include TestHelper

  include ASTUtils::Vertex

  Relationship = ASTUtils::Relationship
  ReachingDefinitionAnalysis = ASTUtils::ReachingDefinitionAnalysis

  def parse(source)
    Parser::Ruby27.parse(source)
  end

  def top_relationship(source)
    node = parse(source)
    rel = Relationship.new(node: node)
    rel.compute_node()
  end

  def def_relationship(source)
    node = parse(source)
    rel = Relationship.new(node: node)
    rel.compute_def
  end

  def test_rd
    rels = top_relationship(<<EOF)
x = 123
y = 234
x + y
EOF

    analysis = ReachingDefinitionAnalysis.new(rels: rels, vars: Set[:x, :y]).analyze()

    assert_equal(
      {
        x: Set[nil].compare_by_identity,
        y: Set[nil].compare_by_identity
      },
      analysis.at_enter(dig(rels.node))
    )

    assert_equal({
                   x: Set[dig(rels.node, 0)].compare_by_identity,
                   y: Set[dig(rels.node, 1)].compare_by_identity
                 },
                 analysis.at_enter(dig(rels.node, 2)))
  end

  def test_loop
    rels = top_relationship(<<EOF)
x = 123

while y = foo()
  puts x
  x = y + 1
  puts x
end
EOF

    analysis = ReachingDefinitionAnalysis.new(rels: rels, vars: Set[:x, :y]).analyze()

    assert_equal(
      {
        x: Set[nil].compare_by_identity,
        y: Set[nil].compare_by_identity
      },
      analysis.at_enter(dig(rels.node, 0))
    )

    assert_equal(
      {
        x: Set[dig(rels.node,0)].compare_by_identity,
        y: Set[nil].compare_by_identity
      },
      analysis.at_leave(dig(rels.node, 0))
    )

    assert_equal(
      {
        x: Set[dig(rels.node,0)].compare_by_identity,
        y: Set[nil].compare_by_identity
      },
      analysis.at_enter(dig(rels.node, 1))
    )

    assert_equal(
      {
        x: Set[dig(rels.node, 0), dig(rels.node, 1, 1, 1)].compare_by_identity,
        y: Set[dig(rels.node, 1, 0)].compare_by_identity
      },
      analysis.at_enter(dig(rels.node, 1, 1))
    )

    assert_equal(
      {
        x: Set[dig(rels.node, 0), dig(rels.node, 1, 1, 1)].compare_by_identity,
        y: Set[dig(rels.node, 1, 0)].compare_by_identity
      },
      analysis.at_leave(dig(rels.node, 1))
    )

    assert_equal(
      {
        x: Set[dig(rels.node, 0), dig(rels.node, 1, 1, 1)].compare_by_identity,
        y: Set[dig(rels.node, 1, 0)].compare_by_identity
      },
      analysis.at_leave(dig(rels.node))
    )
  end

  def test_block
    rels = top_relationship(<<EOF)
x = 123

loop do
  x.bar()
  x = x + 2
  x.foo()
end
EOF

    analysis = ReachingDefinitionAnalysis.new(rels: rels, vars: Set[:x]).analyze()

    assert_equal(
      {
        x: Set[
          dig(rels.node, 0),
          dig(rels.node, 1, 2, 1)
        ].compare_by_identity
      },
      analysis.at_leave(dig(rels.node, 1, 2, 0))
    )

    assert_equal(
      {
        x: Set[
          dig(rels.node, 1, 2, 1)
        ].compare_by_identity
      },
      analysis.at_leave(dig(rels.node, 1, 2, 2))
    )

    assert_equal(
      {
        x: Set[
          dig(rels.node, 0),
          dig(rels.node, 1, 2, 1)
        ].compare_by_identity
      },
      analysis.at_leave(dig(rels.node, 1))
    )
  end

  def test_def
    rels = def_relationship(<<EOF)
def hello(node, a=1, *b, c, d:, e: 3, **f, &g)
  name = 30
  node = nil
end
EOF

    analysis = ReachingDefinitionAnalysis.new(rels: rels, vars: Set[:node, :a, :b, :c, :d, :e, :f, :g, :name]).analyze()

    assert_equal(
      {
        node: Set[dig(rels.node, 1, 0)].compare_by_identity,
        a: Set[dig(rels.node, 1, 1)].compare_by_identity,
        b: Set[dig(rels.node, 1, 2)].compare_by_identity,
        c: Set[dig(rels.node, 1, 3)].compare_by_identity,
        d: Set[dig(rels.node, 1, 4)].compare_by_identity,
        e: Set[dig(rels.node, 1, 5)].compare_by_identity,
        f: Set[dig(rels.node, 1, 6)].compare_by_identity,
        g: Set[dig(rels.node, 1, 7)].compare_by_identity,
        name: Set[nil].compare_by_identity
      },
      analysis.at_enter(dig(rels.node, 2))
    )

    assert_equal(
      {
        node: Set[dig(rels.node, 2, 1)].compare_by_identity,
        a: Set[dig(rels.node, 1, 1)].compare_by_identity,
        b: Set[dig(rels.node, 1, 2)].compare_by_identity,
        c: Set[dig(rels.node, 1, 3)].compare_by_identity,
        d: Set[dig(rels.node, 1, 4)].compare_by_identity,
        e: Set[dig(rels.node, 1, 5)].compare_by_identity,
        f: Set[dig(rels.node, 1, 6)].compare_by_identity,
        g: Set[dig(rels.node, 1, 7)].compare_by_identity,
        name: Set[dig(rels.node, 2, 0)].compare_by_identity
      },
      analysis.at_leave(dig(rels.node, 2))
    )
  end

  def test_masgn
    rels = top_relationship(<<EOF)
x,y,*z = [1,2,3]
EOF

    analysis = ReachingDefinitionAnalysis.new(rels: rels, vars: Set[:x, :y, :z]).analyze()

    assert_equal(
      {
        x: Set[nil].compare_by_identity,
        y: Set[nil].compare_by_identity,
        z: Set[nil].compare_by_identity,
      },
      analysis.at_enter(dig(rels.node))
    )

    assert_equal({
                   x: Set[dig(rels.node)].compare_by_identity,
                   y: Set[dig(rels.node)].compare_by_identity,
                   z: Set[dig(rels.node)].compare_by_identity
                 },
                 analysis.at_leave(dig(rels.node)))
  end

  def test_and_or_assign
    rels = top_relationship(<<EOF)
x = 10
x &&= x+1
x ||= 10
puts x
EOF

    analysis = ReachingDefinitionAnalysis.new(rels: rels, vars: Set[:x]).analyze()

    assert_equal(
      {
        x: Set[nil].compare_by_identity,
      },
      analysis.at_enter(dig(rels.node))
    )

    assert_equal(
      {
        x: Set[
          dig(rels.node, 0),
          dig(rels.node, 1),
          dig(rels.node, 2)
        ].compare_by_identity,
      },
      analysis.at_leave(dig(rels.node))
    )
  end

  def test_op_assign
    rels = top_relationship(<<EOF)
x = 10
x += 10
EOF

    analysis = ReachingDefinitionAnalysis.new(rels: rels, vars: Set[:x]).analyze()

    assert_equal(
      {
        x: Set[nil].compare_by_identity,
      },
      analysis.at_enter(dig(rels.node))
    )

    assert_equal(
      {
        x: Set[
          dig(rels.node, 1),
        ].compare_by_identity,
      },
      analysis.at_leave(dig(rels.node))
    )
  end
end
