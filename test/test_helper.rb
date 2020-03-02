$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require "parser/ruby25"
require "parser/ruby27"
Parser::Builders::Default.emit_lambda = true
Parser::Builders::Default.emit_procarg0 = true

require 'ast_utils'

require 'minitest/autorun'

module TestHelper
  def dig(node, *indexes)
    case indexes.size
    when 0
      node
    when 1
      node.children[indexes.first]
    else
      dig(node.children[indexes.first], *indexes.drop(1))
    end
  end
end
