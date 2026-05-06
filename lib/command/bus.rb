# frozen_string_literal: true

module Command
  class UnknownCommandError < StandardError; end

  # Dispatches commands to registered handlers.
  # Handlers own transaction boundaries so Rails Event Store writes are not rolled back with outer failures.
  class Bus
    def initialize
      @handlers = {}
    end

    def register(service)
      service.class.handler_mappings.each do |command_class, method_name|
        @handlers[command_class] = [service, method_name]
      end
    end

    def call(command)
      handler = @handlers[command.class]
      raise UnknownCommandError, "No handler registered for #{command.class.name}" unless handler

      service, method_name = handler
      service.public_send(method_name, command)
    end
  end
end
