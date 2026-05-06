# frozen_string_literal: true

module HasTypeid
  extend ActiveSupport::Concern

  class_methods do
    def has_typeid(prefix)
      @typeid_prefix = prefix.to_s
    end

    def typeid_prefix
      @typeid_prefix || raise("#{name} must call has_typeid")
    end
  end

  def tid
    "#{self.class.typeid_prefix.to_s.camelize}$#{external_id}"
  end
end
