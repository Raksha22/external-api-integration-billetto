# frozen_string_literal: true

Rails.application.config.to_prepare do
  bus = Command::Bus.new
  bus.register(Guidelines::Service.new)
  Rails.configuration.command_bus = bus
end
