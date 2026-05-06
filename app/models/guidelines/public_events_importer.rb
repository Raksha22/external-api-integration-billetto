# frozen_string_literal: true

module Guidelines
  class PublicEventsImporter
    Result = Struct.new(:imported_count, :updated_count, :skipped_count, :errors, keyword_init: true)

    def initialize(client: Billetto::Client.new)
      @client = client
    end

    def call(limit: 50)
      events = client.list_public_events(limit: limit)
      imported_count = 0
      updated_count = 0
      skipped_count = 0
      errors = []

      events.each do |payload|
        attributes = map_attributes(payload)
        event = Event.find_or_initialize_by(external_id: attributes.fetch(:external_id))
        was_new_record = event.new_record?

        event.assign_attributes(attributes.merge(raw_payload: payload))
        event.save!

        if was_new_record
          imported_count += 1
        else
          updated_count += 1
        end
      rescue KeyError, ArgumentError, ActiveRecord::RecordInvalid => e
        skipped_count += 1
        errors << e.message
      end

      Result.new(
        imported_count: imported_count,
        updated_count: updated_count,
        skipped_count: skipped_count,
        errors: errors
      )
    end

    private

    attr_reader :client

    def map_attributes(payload)
      data = payload.with_indifferent_access
      external_id = fetch_required(data, :id, :uuid)
      title = fetch_required(data, :title, :name)
      starts_at = extract_starts_at(data)

      {
        external_id: external_id.to_s,
        title: title.to_s,
        starts_at: starts_at,
        image_url: extract_image_url(data),
        description: data[:description],
        venue_name: extract_venue_name(data)
      }
    end

    def extract_starts_at(data)
      try_coerce = lambda do |value|
        coerce_to_time(value)
      end

      START_TIME_KEYS.each do |key|
        t = try_coerce.call(data[key])
        return t if t
      end

      %w[event attributes data resource item].each do |wrap|
        inner = data[wrap]
        next unless inner.is_a?(Hash)

        inner = inner.with_indifferent_access
        START_TIME_KEYS.each do |key|
          t = try_coerce.call(inner[key])
          return t if t
        end
      end

      t = try_coerce.call(data[:start])
      return t if t

      data.each_key do |key|
        next unless key.to_s.match?(/start/i)
        next unless key.to_s.match?(/at|date|time|on$/i)

        t = try_coerce.call(data[key])
        return t if t
      end

      sample = data.keys.first(25).join(", ")
      raise KeyError, "No event start time found (tried common Billetto keys; sample keys: #{sample})"
    end

    START_TIME_KEYS = %w[
      starts_at start_time start_date startdate startDate
      event_start event_start_at event_starts_at beginning_at from_date
      start_datetime starts_on begins_at scheduled_start
    ].freeze

    def coerce_to_time(value)
      case value
      when Time, ActiveSupport::TimeWithZone
        value
      when Date, DateTime
        value.to_time.in_time_zone
      when String
        return nil if value.blank?

        parse_datetime(value)
      when Integer, Float
        Time.zone.at(value.to_i)
      when Hash
        h = value.with_indifferent_access
        nested = h[:date].presence || h[:utc].presence || h[:iso8601].presence || h[:datetime].presence
        return parse_datetime(nested) if nested.present?
        return coerce_to_time(h[:timestamp]) if h[:timestamp].present?

        nil
      else
        nil
      end
    end

    def extract_image_url(payload)
      payload[:image_url] || payload.dig(:image, :url)
    end

    def extract_venue_name(payload)
      payload[:venue_name] || payload.dig(:venue, :name)
    end

    def fetch_required(data, *keys)
      keys.each do |key|
        value = data[key]
        return value if value.present?
      end

      raise KeyError, "Missing required keys: #{keys.join(', ')}"
    end

    def parse_datetime(value)
      parsed = Time.zone.parse(value.to_s)
      raise ArgumentError, "Invalid starts_at value: #{value}" if parsed.nil?

      parsed
    end
  end
end
