# frozen_string_literal: true

class ObjectRepository
  class UnknownObjectError < StandardError; end

  def self.find(identifier)
    type, id = identifier.to_s.split("$", 2)
    raise UnknownObjectError, identifier if id.blank?

    case type
    when "Event"
      Guidelines::Event.find_by!(external_id: id)
    else
      raise UnknownObjectError, identifier
    end
  end
end
