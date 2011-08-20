require 'json'

require 'runeo/base'
require 'runeo/relationship_proxy'

module Runeo
  class Node < Base
    class <<self
      def find(id)
        response = connection.get("/db/data/node/#{id.to_i}")
        hash = JSON.parse(response.body)
        new hash["data"].merge("id" => id)
      end

      def create(attrs={})
        payload = attrs.to_json
        response = connection.post("/db/data/node", payload, "application/json")
        hash = JSON.parse(response.body)
        id = extract_id(hash["self"])
        new hash["data"].merge("id" => id)
      end

      def has_many(association_name, options={})
        payload = { max_depth: 1, relationships: [] }
        options[:via].each do |name, direction|
          payload[:relationships] << { direction: direction, type: name }
        end

        class_eval <<-CODE, __FILE__, __LINE__+1
          def #{association_name}
            payload = #{payload.to_json.inspect}
            response = self.class.connection.post("/db/data/node/\#{id}/traverse/node", payload, "application/json")
            JSON.parse(response.body).map do |hash|
              id = self.class.extract_id(hash["self"])
              #{options[:class] || "Runeo::Node"}.new hash["data"].merge("id" => id)
            end
          end
        CODE
      end
    end

    def destroy
      response = self.class.connection.delete("/db/data/node/#{id}")
      return true if response.code == "204"
      raise "unexepcted `delete' response: #{response.code} (#{response.body})"
    end

    def relationships
      @relationships ||= Runeo::RelationshipProxy.new(self)
    end
  end
end
