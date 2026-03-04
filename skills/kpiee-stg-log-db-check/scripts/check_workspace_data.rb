# Usage:
# bundle exec rails runner check_workspace_data.rb -- <workspace_id> [issue_opened_at_iso8601_utc] [table_csv]

require "json"
require "time"

workspace_id = Integer(ARGV.fetch(0))
issue_opened_at = ARGV[1] ? Time.parse(ARGV[1]).utc : nil
requested_tables = ARGV[2]&.split(",")&.map(&:strip)&.reject(&:empty?)

DEFAULT_TABLES = %w[
  messages
  notifications
  message_notification_settings
  data_update_notification_settings
  push_deliveries
  push_delivery_results
  mail_deliveries
  mail_delivery_results
  slack_deliveries
  line_deliveries
  chatwork_deliveries
  teams_deliveries
  google_chat_deliveries
].freeze

TARGET_TABLES = requested_tables&.any? ? requested_tables : DEFAULT_TABLES

def table_stats(connection, table_name, since_at)
  return nil unless connection.data_source_exists?(table_name)

  quoted = connection.quote_table_name(table_name)
  cols = connection.columns(table_name).map(&:name)

  stats = {
    table: table_name,
    total_count: connection.select_value("SELECT COUNT(*) FROM #{quoted}").to_i
  }

  if cols.include?("created_at")
    latest = connection.select_value("SELECT MAX(created_at) FROM #{quoted}")
    stats[:latest_created_at] = latest&.utc&.iso8601

    if since_at
      val = connection.select_value(
        sanitize_sql(["SELECT COUNT(*) FROM #{quoted} WHERE created_at >= ?", since_at])
      )
      stats[:count_since_issue] = val.to_i
    end
  end

  if cols.include?("updated_at")
    latest = connection.select_value("SELECT MAX(updated_at) FROM #{quoted}")
    stats[:latest_updated_at] = latest&.utc&.iso8601
  end

  stats
end

# ActiveRecord sanitize helper without model context

def sanitize_sql(array)
  ActiveRecord::Base.send(:sanitize_sql_array, array)
end

out = {
  workspace_id: workspace_id,
  issue_opened_at_utc: issue_opened_at&.iso8601,
  account_db_connection: nil,
  account_db: nil,
  table_stats: [],
  missing_tables: [],
  errors: []
}

conn = DbConnection::AccountDbConnection.find_by(account_id: workspace_id)
out[:account_db_connection] = conn&.attributes&.slice("account_id", "host", "port", "database", "db_created_at")

begin
  AccountRecord.connect(account_id: workspace_id) do
    out[:account_db] = AccountRecord.connection.current_database
    connection = AccountRecord.connection

    TARGET_TABLES.each do |table_name|
      begin
        stats = table_stats(connection, table_name, issue_opened_at)
        if stats
          out[:table_stats] << stats
        else
          out[:missing_tables] << table_name
        end
      rescue => e
        out[:errors] << { table: table_name, error: "#{e.class}: #{e.message}" }
      end
    end
  end
rescue => e
  out[:errors] << { scope: "AccountRecord.connect", error: "#{e.class}: #{e.message}" }
end

puts JSON.pretty_generate(out)
