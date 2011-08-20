require "runeo/node"

module Runeo
  class HasManyProxy
    include Enumerable

    def initialize(anchor, options)
      @anchor = anchor
      @options = options
    end

    def each
      load!

      if block_given?
        @_result.each { |node| yield node }
        self
      else
        @_result.to_enum
      end
    end

    def length
      load!
      @_result.length
    end

    def create(attributes={})
      check_via_conditions!
      node_class = (@options[:class] || "Runeo::Node").constantize
      push(node_class.create(attributes))
    end

    def push(node)
      check_via_conditions!

      via_type, via_direction = @options[:via].first
      if via_direction == :in
        from, to = node, @anchor
      else
        from, to = @anchor, node
      end

      from.relationships.create to, via_type
      node
    end

    private

    def check_via_conditions!
      raise ArgumentError, "ambiguous #create due to too many :via specs" if @options[:via].length > 1
      raise ArgumentError, "ambiguous #create due to :all direction" if @options[:via].first[1] == :all
    end

    def load!
      @_result ||= begin
        payload = { max_depth: 1, relationships: [] }
        @options[:via].each do |name, direction|
          payload[:relationships] << { direction: direction, type: name }
        end

        response = @anchor.class.connection.post("/db/data/node/#{@anchor.id}/traverse/node", payload.to_json, "application/json")

        JSON.parse(response.body).map do |hash|
          Runeo::Node.instantiate(hash)
        end
      end
    end
  end
end
