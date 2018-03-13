# ASTUtils

ASTUtils provides some utility over parser gem AST, which aims to help analyzing Ruby programs.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ast_utils'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ast_utils

## Usage

### ASTUtils::Labeling

`ASTUTils::Labeling` implements local variables labeling.

In Ruby, local variable scope can be nested, and identification on local variables is not trivial.
This utility give labels to identify local variables.

```rb
require "parser/current"
require "ast_utils"

node = Parser::CurrentRuby.parse(source)
labeled = ASTUtils::Labeling.translate(node: node)
```

### ASTUTils::Navigation

`AST` has `children` but no pointer to its parent.

```rb
require "parser/current"
require "ast_utils"

node = Parser::CurrentRuby.parse(source)
navigation = ASTUtils::Navigation.from(node: node)

parent = navigation.parent(child_node)
```

### ASTUtils::Scope

`Scope` is about *scope* in Ruby.

It associates outer scope and its inner scope.

```rb
require "parser/current"
require "ast_utils"

node = Parser::CurrentRuby.parse(source)
labeled = ASTUtils::Labeling.translate(node: node)
scope = ASTUtils::Scope.from(node: labeled)

scope.root
scope.children(root)
scope.subs(root)
```

`children` includes `def` and iterator block, but `subs` only includes blocks.

It also defines `assignments` and `references` to refere assignments and references for local variables in the scope.

`assignments` returns pair of:

* Node which implements assignment
* Labeled local variable name which is assigned

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/soutaro/ast_utils.

