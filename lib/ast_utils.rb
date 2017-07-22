require "ast_utils/version"

require "parser/current"
require "pathname"
require "set"

require "ast_utils/node_set"
require "ast_utils/node_helper"
require "ast_utils/partial_map"
require "ast_utils/labeling"
require "ast_utils/navigation"
require "ast_utils/scope"

Parser::Builders::Default.emit_lambda = true
Parser::Builders::Default.emit_procarg0 = true
