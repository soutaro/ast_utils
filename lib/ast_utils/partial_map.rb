module ASTUtils
  class PartialMap
    attr_reader :enumerable
    attr_reader :updaters

    def initialize(enumerable)
      @enumerable = enumerable
      @updaters = Array.new(enumerable.count)
    end

    def self.apply(enumerable)
      map = new(enumerable)
      yield map
      map.apply
    end

    def on(index, &block)
      updaters[index] = [:on, block]
    end

    def on!(index, &block)
      updaters[index] = [:on!, block]
    end

    def on?(index, &block)
      updaters[index] = [:on?, block]
    end

    def apply
      enumerable.map.with_index do |value, index|
        updater = updaters[index]

        if updater
          case updater&.first
          when :on
            updater.last[value]
          when :on!
            raise if value.nil?
            updater.last[value]
          when :on?
            unless value.nil?
              updater.last[value]
            else
              value
            end
          end
        else
          value
        end
      end
    end
  end
end
