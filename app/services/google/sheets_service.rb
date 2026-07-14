require "google/apis/sheets_v4"

module Google
  class SheetsService
    SPREADSHEET_ID = "1EOzM0w3MRkDhmhDIJpRkvDlfu2QC_UeWOCSkeAnhX0Y".freeze
    RANGE = "Sheet1!A:L".freeze

    HEADERS = %w[
      id name email phone country age gender company job_title salary status joining_date
    ].freeze

    HEADER_LABELS = {
      "id" => "ID",
      "name" => "Name",
      "email" => "Email",
      "phone" => "Phone",
      "country" => "Country",
      "age" => "Age",
      "gender" => "Gender",
      "company" => "Company",
      "job_title" => "Job Title",
      "salary" => "Salary",
      "status" => "Status",
      "joining_date" => "Joining Date"
    }.freeze

    def initialize(user)
      @user = user
    end

    def users
      return @cached_users if defined?(@cached_users)

      rows = read_sheet
      if rows.blank?
        @cached_users = []
        return @cached_users
      end

      headers = rows.shift.map { |h| normalize_header(h) }

      @cached_users = rows.map do |row|
        padded = row + Array.new([headers.size - row.size, 0].max, "")
        headers.zip(padded.first(headers.size)).to_h
      end
    end

    def filter_users(query: nil, country: nil, status: nil)
      result = users

      if query.present?
        q = query.to_s.strip
        pattern = /\b#{Regexp.escape(q)}/i
        result = result.select do |row|
          row.values.any? { |value| value.to_s.match?(pattern) }
        end
      end

      if country.present?
        result = result.select { |row| row["country"].to_s == country }
      end

      if status.present?
        result = result.select { |row| row["status"].to_s.downcase == status.to_s.downcase }
      end

      result
    end

    def countries
      users.map { |row| row["country"].to_s }.reject(&:blank?).uniq.sort
    end

    def statuses
      users.map { |row| row["status"].to_s }.reject(&:blank?).uniq.sort
    end

    def to_csv(rows)
      lines = []
      lines << HEADERS.map { |header| csv_escape(HEADER_LABELS[header]) }.join(",")

      rows.each do |row|
        lines << HEADERS.map { |header| csv_escape(row[header].to_s) }.join(",")
      end

      "#{lines.join("\n")}\n"
    end

    private

    attr_reader :user

    def csv_escape(value)
      string = value.to_s
      if string.include?(",") || string.include?('"') || string.include?("\n") || string.include?("\r")
        "\"#{string.gsub('"', '""')}\""
      else
        string
      end
    end

    def normalize_header(header)
      header.to_s.downcase.strip.gsub(/\s+/, "_")
    end

    def read_sheet
      response = sheets_service.get_spreadsheet_values(SPREADSHEET_ID, RANGE)
      response.values || []
    end

    def sheets_service
      service = Google::Apis::SheetsV4::SheetsService.new
      service.authorization = authorization
      service
    end

    def authorization
      client = Signet::OAuth2::Client.new(
        client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
        token_credential_uri: "https://oauth2.googleapis.com/token",
        refresh_token: user.refresh_token
      )

      client.fetch_access_token!
      client
    end
  end
end
