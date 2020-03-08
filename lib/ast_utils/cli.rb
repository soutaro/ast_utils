require "thor"
require "parser/ruby27"

module ASTUtils
  class CLI < Thor
    desc "label SCRIPTS...", "labeling Ruby scripts given as SCRIPTS..."
    def label(*scripts)
      scripts.map {|script| Pathname(script) }.each do |path|
        puts "Parsing #{path}..."
        node = Parser::Ruby25.parse(path.read, path.to_s)
        puts "Translating node..."
        labeled = Labeling.translate(node: node)
        puts "#{labeled.inspect}"
      end
    end

    desc "rel SCRIPTS...", "relationship between nodes in scripts..."
    def rel(*scripts)
      scripts.map {|script| Pathname(script) }.each do |path|
        STDERR.puts "Parsing #{path}..."
        node = Parser::Ruby27.parse(path.read, path.to_s)

        rels = []

        rel = Relationship.new(node: node) do |def_node|
          rels << Relationship.new(node: def_node).compute_def
        end
        rels << rel

        rel.compute_node

        # puts "digraph rels {"
        # rels.each do |rel|
        #   rel.each_edge do |from, to|
        #     puts "\"#{from}\" -> \"#{to}\""
        #   end
        # end
        # puts "}"

        rels.each do |rel|
          case rel.node.type
          when :def
            puts "#{rel.node.type}:#{rel.node.children[0]} (#{rel.node.loc.line}:#{rel.node.loc.column})"
          else
            puts "#{rel.node.type} (#{rel.node.loc.line}:#{rel.node.loc.column})"
          end
          vars = rel.all_variables
          puts "  #{vars.to_a.join(", ")}"
          start = Time.now
          ReachingDefinitionAnalysis.new(rels: rel, vars: vars).analyze
          puts "  ~> RDA took #{Time.now - start} secs"
        end
      end
    end
  end
end
