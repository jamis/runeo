require 'json'
require 'active_support/core_ext/string'

require 'runeo/base'
require 'runeo/has_many_proxy'
require 'runeo/relationship_proxy'

module Runeo
  class Node < Base
    class <<self
      def find(id)
        response = connection.get("/db/data/node/#{id.to_i}")
        instantiate JSON.parse(response.body)
      end

      def instantiate(hash)
        id = extract_id(hash["self"])
        data = hash["data"] || {}
        type = data["_type"] || "Runeo::Node"
        type.constantize.new data.merge("id" => id)
      end

      def create(attrs={})
        payload = attrs.merge(_type: self.name).to_json
        response = connection.post("/db/data/node", payload, "application/json")
        instantiate JSON.parse(response.body)
      end

      def has_many(association_name, options={})
        class_eval <<-CODE, __FILE__, __LINE__+1
          def #{association_name}
            @_#{association_name} ||= Runeo::HasManyProxy.new(self, #{options.inspect})
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
