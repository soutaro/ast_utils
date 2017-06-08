require "ast_utils/version"

require "parser/current"
require "pathname"

require "ast_utils/node_helper"
require "ast_utils/partial_map"
require "ast_utils/labeling"

Parser::Builders::Default.emit_lambda = true
Parser::Builders::Default.emit_procarg0 = true
