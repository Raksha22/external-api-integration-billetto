# frozen_string_literal: true

# Domain events published by domain modules
class Fact < RubyEventStore::Event
  def self.strict(data:)
    payload = data.deep_symbolize_keys
    validate_schema!(payload) if const_defined?(:SCHEMA)
    new(data: payload)
  end

  def self.validate_schema!(data)
    self::SCHEMA.each_key do |key|
      raise ArgumentError, "Missing key :#{key} for #{name}" unless data.key?(key)
    end
  end

  def stream_names
    []
  end
end
