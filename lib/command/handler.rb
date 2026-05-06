# frozen_string_literal: true

module Command
  module Handler
    extend ActiveSupport::Concern

    class_methods do
      def handles(command_class, method_name)
        @handler_mappings ||= {}
        @handler_mappings[command_class] = method_name
      end

      def handler_mappings
        @handler_mappings || {}
      end
    end

    def event_store
      Rails.configuration.event_store
    end

    def command_bus
      Rails.configuration.command_bus
    end
  end
end
