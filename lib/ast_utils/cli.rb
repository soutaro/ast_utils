require "thor"

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
  end
end
