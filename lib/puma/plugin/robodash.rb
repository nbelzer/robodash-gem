# frozen_string_literal: true
require "puma/plugin"
require "robodash"

Puma::Plugin.create do
  def start(launcher)
    return unless Robodash.api_token

    in_background do
      loop do
        sleep 1 # second
        collect_and_report_metrics
      rescue => e
        Puma::LogWriter.stdio.log "Metrics collection error: #{e.message}"
      end
    end
  end

  def collect_and_report_metrics
    stats = Puma.stats_hash
    if stats[:worker_status]
      worker_stats = stats.dig(:worker_status)
      Robodash.measure("Puma Workers", stats.dig(:workers))
      Robodash.measure("Puma Backlog", worker_stats.sum { _1.dig(:last_status, :backlog) })
      Robodash.measure("Puma Running", worker_stats.sum { _1.dig(:last_status, :running) })
      Robodash.measure("Puma Capacity", worker_stats.sum { _1.dig(:last_status, :pool_capacity) })
    else
      Robodash.measure("Puma Backlog", stats[:backlog])
      Robodash.measure("Puma Running", stats[:running])
      Robodash.measure("Puma Busy", stats[:busy_threads])
      Robodash.measure("Puma Capacity", stats[:pool_capacity])
    end
  end
end
