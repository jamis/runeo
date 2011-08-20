require 'runeo/relationship'

module Runeo
  class RelationshipProxy
    attr_reader :anchor

    def initialize(anchor)
      @anchor = anchor
    end

    def length
      relationships.length
    end

    def create(other, type)
      Runeo::Relationship.create(@anchor.id, other.id, type)
    end

    private

    def relationships
      @relationships ||= Runeo::Relationship.find_on(@anchor, :all)
    end
  end
end
