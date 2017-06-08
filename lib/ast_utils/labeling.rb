module ASTUtils
  class Labeling
    class LabeledName
      attr_reader :name
      attr_reader :label

      def initialize(name:, label:)
        @name = name
        @label = label
      end

      def inspect
        "#{name}@#{label}"
      end

      def hash
        name.hash ^ label.hash
      end

      def ==(other)
        other.is_a?(LabeledName) && other.name == name && other.label == label
      end

      def equal?(other)
        self == other
      end

      def eql?(other)
        self == other
      end
    end

    include NodeHelper

    attr_accessor :counter

    def initialize
      self.counter = 0
    end

    def next_label!
      self.counter += 1

      new_label = self.counter

      if block_given?
        yield new_label
      else
        new_label
      end
    end

    def translate(node, env)
      case node.type
      when :lvasgn
        children = PartialMap.apply(node.children) do |map|
          map.on!(0) {|name| lookup_env(name: name, env: env) }
          map.on?(1) {|child| translate(child, env) }
        end

        node.updated(nil, children, nil)

      when :lvar
        children = replace(node.children, 0) {|name| lookup_env(name: name, env: env) }
        node.updated(nil, children, nil)

      when :arg, :restarg, :kwarg, :kwrestarg, :blockarg
        name = node.children[0]

        labeled_name = LabeledName.new(name: name, label: next_label!)
        env[name] = labeled_name

        children = replace(node.children, 0) {|_| labeled_name }
        node.updated(nil, children, nil)

      when :optarg, :kwoptarg
        children = PartialMap.apply(node.children) do |map|
          map.on!(0) {|name| lookup_env(name: name, env: env) }
          map.on?(1) {|child| translate(child, env) }
        end

        node.updated(nil, children, nil)

      when :def
        env_ = {}
        children = map_child_node(node) {|child| translate(child, env_) }
        node.updated(nil, children, nil)

      when :block
        children = node.children.dup
        translate_child!(children, 0, env)

        block_env = env.dup
        translate_child!(children, 1, block_env)
        translate_child!(children, 2, block_env)

        node.updated(nil, children, nil)

      when :class
        children = PartialMap.apply(node.children) do |map|
          map.on!(0) {|child| translate(child, env) }
          map.on?(1) {|child| translate(child, env) }
          map.on?(2) {|child| translate(child, {}) }
        end

        node.updated(nil, children, nil)

      when :module
        children = PartialMap.apply(node.children) do |map|
          map.on!(0) {|child| translate(child, env) }
          map.on?(1) {|child| translate(child, {}) }
        end

        node.updated(nil, children, nil)

      else
        children = map_child_node(node) {|child| translate(child, env) }
        node.updated(nil, children, nil)
      end
    end

    def lookup_env(name:, env:)
      labeled_name = env[name]

      unless labeled_name
        labeled_name = LabeledName.new(name: name, label: next_label!)
        env[name] = labeled_name
      end

      labeled_name
    end

    def translate_child!(children, index, env)
      if children[index]
        children[index] = translate(children[index], env)
      end
    end

    def replace(array, index)
      array = array.dup
      array[index] = yield(array[index])
      array
    end

    def self.translate(node:)
      self.new.translate(node, {})
    end
  end
end
