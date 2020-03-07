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

    analysis = ReachingDefinitionAnalysis.new(rels: rels, fvs: Set[:x, :y]).analyze()

    assert_equal(
      {
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

    analysis = ReachingDefinitionAnalysis.new(rels: rels, fvs: Set[:x, :y]).analyze()

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

  def test_def_block
    rels = def_relationship(<<EOF)
def hello(node, a=1, *b, c, d:, e: 3, **f, &g)
  name = 30
end
EOF

    analysis = ReachingDefinitionAnalysis.new(rels: rels, fvs: Set[]).analyze()

    assert_equal(
      {
        node: Set[dig(rels.node, 1, 0)].compare_by_identity
      },
      analysis.at_enter(dig(rels.node, 2))
    )
  end
end
