namespace :billetto do
  desc "Fetch and import public events from Billetto API"
  task import_events: :environment do
    cmd = Guidelines::SyncPublicEvents.new(limit: ENV.fetch("BILLETTO_IMPORT_LIMIT", 50).to_i)
    unless cmd.valid?
      warn cmd.errors.full_messages.join(", ")
      exit 1
    end

    result = Rails.configuration.command_bus.call(cmd)

    puts "Imported: #{result.imported_count}"
    puts "Updated: #{result.updated_count}"
    puts "Skipped: #{result.skipped_count}"

    if result.errors.any?
      puts "Errors:"
      result.errors.each { |error| puts " - #{error}" }
    end
  rescue Billetto::Error => e
    warn "Billetto import failed: #{e.message}"
    exit 1
  end
end
