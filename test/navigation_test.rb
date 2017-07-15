require "test_helper"

class NavigationTest < Minitest::Test
  include ASTUtils::NodeHelper

  def parse(source)
    Parser::CurrentRuby.parse(source)
  end

  def test_parents
    node = parse(<<-EOS)
def foo(x, y, z)
  x.bar {|a|
    a + y + z
  }
end

foo(1, 2, 3)
    EOS

    navigation = ASTUtils::Navigation.from(node: node)

    navigation.nodes.each do |node|
      unless node.equal?(navigation.root)
        refute_nil navigation.parent(node)

        each_child_node(node) do |child|
          parent = navigation.parent(child)
          assert_operator node, :equal?, parent
        end
      else
        assert_nil navigation.parent(node)
      end
    end
  end
end
