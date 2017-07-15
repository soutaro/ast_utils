require "test_helper"

class NodeSetTest < Minitest::Test
  def parse(source)
    Parser::CurrentRuby.parse(source)
  end

  def test_set
    n1 = parse("x = 3")
    n2 = parse("x = 3")

    assert_equal n1, n2
    refute(n1.equal?(n2))

    set = ASTUtils::NodeSet.new([n1, n2])

    set << n1

    assert_equal 2, set.size
    assert_equal 1, set.each.count {|other| other.equal?(n1) }
    assert_equal 1, set.each.count {|other| other.equal?(n2) }
  end

  def test_add
    n1 = parse("x = 3")
    n2 = parse("x = 3")

    set = ASTUtils::NodeSet.new

    set << n1
    set << n2
    set << n1

    assert_equal 2, set.size
    assert_equal 1, set.each.count {|other| other.equal?(n1) }
    assert_equal 1, set.each.count {|other| other.equal?(n2) }
  end

  def test_delete
    n1 = parse("x = 3")
    n2 = parse("x = 3")

    set = ASTUtils::NodeSet.new

    set << n1
    set << n2
    set.delete n1

    assert_equal 1, set.size
    assert_equal 0, set.each.count {|other| other.equal?(n1) }
    assert_equal 1, set.each.count {|other| other.equal?(n2) }
  end
end
