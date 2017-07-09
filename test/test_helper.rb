$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'ast_utils'

require 'minitest/autorun'

module TestHelper
  def dig(node, *indexes)
    if indexes.size == 1
      node.children[indexes.first]
    else
      dig(node.children[indexes.first], *indexes.drop(1))
    end
  end
end
