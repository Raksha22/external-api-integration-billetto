class EventsController < ApplicationController
  def index
    @events = Guidelines::Event.ordered
  end

  def sync
    cmd = Guidelines::SyncPublicEvents.new(limit: sync_limit_param)
    unless cmd.valid?
      redirect_to events_path, alert: cmd.errors.full_messages.to_sentence and return
    end

    result = command_bus.call(cmd)
    message = "Sync complete: #{result.imported_count} imported, #{result.updated_count} updated"
    message += ", #{result.skipped_count} skipped" if result.skipped_count.positive?

    redirect_to events_path, notice: message
  rescue Billetto::Error => e
    redirect_to events_path, alert: "Billetto sync failed: #{e.message}"
  rescue Command::UnknownCommandError => e
    redirect_to events_path, alert: e.message
  end

  private

  def sync_limit_param
    v = params[:limit].presence&.to_i
    v.nil? || v <= 0 ? 50 : v
  end
end
