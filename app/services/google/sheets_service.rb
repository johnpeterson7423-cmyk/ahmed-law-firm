require "google/apis/sheets_v4"

module Google
  # Read-only access to the firm roster spreadsheet.
  # Never update, append, clear, or delete sheet/Drive data — fetch values only.
  #
  # Rows with a red, green, purple, or lavender highlight on the client column (A)
  # are excluded. Values and colors are fetched separately so the payload stays small.
  class SheetsService
    # TODO: replace with the real client-roster spreadsheet ID.
    SPREADSHEET_ID = "1Fe9eGkwM9N9yEdiD8CT5kT0nHH0rxXUC3tNqJrGoMwM".freeze
    VALUES_RANGE = "Sheet1!A:N".freeze
    CACHE_TTL = 2.minutes
    EXCLUDED_HIGHLIGHTS = %i[red green purple lavender].freeze

    HEADERS = RosterTable::HEADERS
    HEADER_LABELS = RosterTable::HEADER_LABELS

    # Per-process cache so pagination/filter requests don't re-hit Google every time.
    SHEET_CACHE = ActiveSupport::Cache::MemoryStore.new

    def initialize(user)
      @user = user
    end

    def users
      table.users
    end

    def filter_users(query: nil, insurance: nil, status: nil)
      table.filter_users(query: query, insurance: insurance, status: status)
    end

    def insurances
      table.insurances
    end

    def statuses
      table.statuses
    end

    private

    attr_reader :user

    def table
      @table ||= RosterTable.new(read_sheet)
    end

    def read_sheet
      SHEET_CACHE.fetch(cache_key, expires_in: CACHE_TTL) { fetch_sheet_rows }
    end

    def cache_key
      "roster/v3/#{SPREADSHEET_ID}/#{user.id}/#{user.token_expires_at.to_i}"
    end

    def fetch_sheet_rows
      values = fetch_values
      return [] if values.blank?

      highlights = fetch_column_a_highlights(values.size)

      values.each_with_index.filter_map do |row, index|
        # Always keep the header row (index 0).
        next row if index.zero?
        next if row.all?(&:blank?)
        next if highlights[index].in?(EXCLUDED_HIGHLIGHTS)

        row
      end
    end

    def fetch_values
      response = sheets_service.get_spreadsheet_values(
        SPREADSHEET_ID,
        VALUES_RANGE,
        value_render_option: "FORMATTED_VALUE"
      )

      (response.values || []).map { |row| row.map { |cell| cell.to_s } }
    end

    # Only column A colors for the rows we already loaded.
    def fetch_column_a_highlights(row_count)
      spreadsheet = sheets_service.get_spreadsheet(
        SPREADSHEET_ID,
        ranges: ["Sheet1!A1:A#{row_count}"],
        include_grid_data: true,
        fields: "sheets.data.rowData.values.effectiveFormat.backgroundColor"
      )

      row_data = spreadsheet.sheets&.first&.data&.first&.row_data || []

      Array.new(row_count) do |index|
        cell = row_data[index]&.values&.first
        highlight_color(cell&.effective_format&.background_color)
      end
    end

    def highlight_color(color)
      return nil if color.nil?

      r = color.red || 0.0
      g = color.green || 0.0
      b = color.blue || 0.0

      # Soft lavender used in the sheet: ~rgb(0.71, 0.66, 0.84)
      return :lavender if lavender_fill?(r, g, b)

      max = [r, g, b].max
      min = [r, g, b].min
      delta = max - min

      # Ignore white / gray / near-neutral fills (incl. light alternating row tints).
      return nil if delta < 0.08

      saturation = max.zero? ? 0.0 : delta / max
      return nil if saturation < 0.25
      return nil if max < 0.35 # too dark to be a normal sheet highlight

      hue =
        if max == r
          60 * (((g - b) / delta) % 6)
        elsif max == g
          60 * (((b - r) / delta) + 2)
        else
          60 * (((r - g) / delta) + 4)
        end

      return :red if hue < 15 || hue >= 345
      return :green if hue.between?(85, 150)
      return :purple if hue.between?(260, 330)

      nil
    end

    # Pastel purple/lavender fills that fail the normal saturation threshold.
    def lavender_fill?(r, g, b)
      b >= 0.75 &&
        r.between?(0.55, 0.85) &&
        g.between?(0.45, 0.80) &&
        b > r &&
        b > g &&
        (b - g) >= 0.10
    end

    def sheets_service
      @sheets_service ||= begin
        service = Google::Apis::SheetsV4::SheetsService.new
        service.authorization = authorization
        service
      end
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
