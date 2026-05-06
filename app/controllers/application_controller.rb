class ApplicationController < ActionController::Base
  protected

  def command_bus
    Rails.configuration.command_bus
  end
end
