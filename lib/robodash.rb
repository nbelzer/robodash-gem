# frozen_string_literal: true

require_relative "robodash/version"
require "net/http"
require "uri"
require "json"

module Robodash
  # Defaults
  DEFAULT_HOST = "https://robodash.app"
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  # Parse flexible format like "every 30 minutes", "3 days", "2 hours"
  SCHEDULE_REGEX = /^(?:every\s+)?(\d+)\s*(minute|hour|day|week|month|year)s?$/

  class << self
    attr_accessor :api_token, :host, :enabled

    def enabled?
      return true if @enabled.nil?
      @enabled
    end

    # Possible schedules:
    # - minutely
    # - hourly
    # - daily
    # - weekly
    # - monthly
    # - yearly
    #
    # Examples:
    # Robodash.ping("Some task", :daily, grace_period: 10.minutes)
    # Robodash.ping("Some task", "every 10 minutes", grace_period: 10.minutes)
    def ping(name, schedule = nil, grace_period: nil)
      params = {name: name}
      params.merge!({grace_period: grace_period.to_i}) if grace_period.present?
      params.merge!(parse_schedule(schedule)) if schedule.present?

      fire_and_forget("ping", params)
    end

    # Count should always be an integer
    def count(name, count, range = nil)
      fire_and_forget("count", {name: name, count: count.to_i})
    end

    # Track values for a specific measurement over time
    # Includes a client-side timestamp by default.
    def measure(name, value, unit = nil, timestamp = Time.now.utc)
      fire_and_forget("measurements", { name:, value:, unit:, timestamp: }.compact)
    end

    def finish_up!
      threads.each(&:join)
    end

    private

      def threads
        @threads ||= []
      end

      def track_thread(&block)
        threads << Thread.new(&block)
        threads.select!(&:alive?)
      end

      def parse_schedule(schedule)
        schedule = schedule.to_s.strip.downcase
        return predefined_schedules[schedule] if predefined_schedules[schedule]

        match = schedule.match(SCHEDULE_REGEX)
        return {schedule_number: match[1].to_i, schedule_period: match[2]} if match

        {}
      end

      def predefined_schedules
        {
          "minutely" => {schedule_period: "minute", schedule_number: 1},
          "hourly" => {schedule_period: "hour", schedule_number: 1},
          "daily" => {schedule_period: "day", schedule_number: 1},
          "weekly" => {schedule_period: "week", schedule_number: 1},
          "monthly" => {schedule_period: "month", schedule_number: 1},
          "yearly" => {schedule_period: "year", schedule_number: 1}
        }
      end

      def fire_and_forget(endpoint, body)
        return false unless enabled?
        return false unless api_token

        track_thread do
          Thread.current.abort_on_exception = false

          begin
            send_api_request(endpoint, body)
          rescue => e
            warn_safely("Robodash request failed: #{e.class} - #{e.message}")
          end
        end

        true
      end

      def send_api_request(endpoint, body)
        uri = URI("#{host}/api/#{endpoint}.json")

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "dashboard-token #{api_token}"
        request["Content-Type"] = "application/json"
        request.body = body.to_json

        # Use aggressive timeouts for fire-and-forget
        Net::HTTP.start(uri.hostname, uri.port,
                        use_ssl: uri.scheme == "https",
                        open_timeout: OPEN_TIMEOUT,
                        read_timeout: READ_TIMEOUT,
                        ssl_timeout: OPEN_TIMEOUT) do |http|
          http.request(request)
        end
      end

      # Only warn if we're in a context where it's safe to do so
      def warn_safely(message)
        if defined?(Rails) && Rails.logger
          Rails.logger.warn("[Robodash] #{message}")
        elsif $stderr && !$stderr.closed?
          $stderr.puts("[Robodash] #{message}")
        end
      rescue
        # If even logging fails, just silently continue
      end

      def host
        @host || DEFAULT_HOST
      end

  end
end

at_exit do
  Robodash.finish_up!
end
