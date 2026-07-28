module Google
  # Background checkup bot: opens each case file, reads the last note date,
  # and saves each result to the database. Read-only on Drive/Sheets.
  class CheckupReportService
    NOTE_DATE = /(?:^|\R)\s*(\d{1,2}\/\d{1,2}\/\d{2,4})\s*:/.freeze
    ANY_DATE = /(\d{1,2}\/\d{1,2}\/\d{2,4})/.freeze

    DEFAULT_LIMIT = 25
    MAX_LIMIT = 600
    DAYS_BEFORE_CALL = 15

    def initialize(checkup_run)
      @run = checkup_run
      @user = checkup_run.user
      @clients = Array(checkup_run.clients_payload)
    end

    def call
      @run.update!(
        status: "running",
        started_at: Time.current,
        scanned: 0,
        found_count: 0,
        not_found_count: 0,
        error: nil
      )

      drive = Google::DriveService.new(@user)

      @clients.each do |row|
        client = row["clients"].to_s.strip
        dol = row["dol"].to_s.strip

        attrs =
          if client.blank?
            blank_client_attrs(client, dol)
          else
            scan_client(drive, client, dol)
          end

        @run.checkup_results.create!(attrs)

        found = attrs[:status] == "found"
        @run.update!(
          scanned: @run.scanned + 1,
          found_count: @run.found_count + (found ? 1 : 0),
          not_found_count: @run.not_found_count + (found ? 0 : 1),
          last_client: client.presence
        )
      end

      @run.update!(status: "done", finished_at: Time.current)
    rescue StandardError => e
      @run.update!(
        status: "error",
        error: e.message,
        finished_at: Time.current
      )
      raise
    end

    private

    def blank_client_attrs(client, dol)
      with_needs_to_call(
        client: client,
        dol: dol,
        status: "not_found",
        error: "Missing client name"
      )
    end

    def scan_client(drive, client, dol)
      document = drive.read_by_client_and_dol(client, dol)
      date = extract_last_checkup_date(document.content)

      if date.present?
        with_needs_to_call(
          client: client,
          dol: dol,
          last_checkup_date: date,
          status: "found",
          document_name: document.name
        )
      else
        with_needs_to_call(
          client: client,
          dol: dol,
          last_checkup_date: nil,
          status: "not_found",
          document_name: document.name,
          error: "Opened file but no checkup date found at the end"
        )
      end
    rescue Google::DriveService::NotFoundError => e
      with_needs_to_call(client: client, dol: dol, status: "not_found", error: e.message)
    rescue Google::Apis::ClientError, Google::Apis::ServerError, Signet::AuthorizationError => e
      with_needs_to_call(client: client, dol: dol, status: "not_found", error: e.message)
    rescue StandardError => e
      with_needs_to_call(client: client, dol: dol, status: "not_found", error: e.message)
    end

    def with_needs_to_call(attrs)
      attrs.merge(needs_to_call: needs_to_call?(attrs[:last_checkup_date]))
    end

    # True only when a last checkup date exists and is 15+ days old.
    def needs_to_call?(date_string)
      parsed = parse_checkup_date(date_string)
      return false if parsed.nil?

      parsed <= Date.current - DAYS_BEFORE_CALL
    end

    def parse_checkup_date(value)
      text = value.to_s.strip
      return nil if text.blank?

      parts = text.split("/")
      return nil unless parts.size == 3

      month, day, year = parts.map(&:to_i)
      return nil if month.zero? || day.zero? || year.zero?

      year += 2000 if year < 100
      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end

    def extract_last_checkup_date(content)
      text = content.to_s
      return nil if text.blank?

      note_dates = text.scan(NOTE_DATE).flatten
      return note_dates.last if note_dates.any?

      tail = text.length > 2500 ? text[-2500..] : text
      tail.scan(ANY_DATE).flatten.last
    end
  end
end
