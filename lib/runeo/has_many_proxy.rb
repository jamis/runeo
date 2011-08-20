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

    private

    def load!
      @_result ||= begin
        payload = { max_depth: 1, relationships: [] }
        @options[:via].each do |name, direction|
          payload[:relationships] << { direction: direction, type: name }
        end

        response = @anchor.class.connection.post("/db/data/node/#{@anchor.id}/traverse/node", payload.to_json, "application/json")

        JSON.parse(response.body).map do |hash|
          id = @anchor.class.extract_id(hash["self"])
          (@options[:class] || Runeo::Node).new hash["data"].merge("id" => id)
        end
      end
    end
  end
end
