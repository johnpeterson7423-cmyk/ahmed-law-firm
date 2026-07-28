require "google/apis/drive_v3"
require "stringio"
require "date"

module Google
  # Read-only access to case files in Drive.
  # Never create, update, or delete Drive files — list / export / download only.
  #
  # Structure:
  #   BI folder → client folder "Last, First (MM/DD/YY)" → document(s) inside
  # Also supports loose files named "First Last (MM/DD/YY)" or without parentheses.
  #
  # Lookup: first name + DOL, then pick the best-scoring match; if it's a folder,
  # open the best document inside it.
  class DriveService
    NotFoundError = Class.new(StandardError)

    # https://drive.google.com/drive/folders/1wQJDxR4DYYD9J4b9E6SpQcNzF7279UP9
    CASE_FILES_FOLDER_ID = "1wQJDxR4DYYD9J4b9E6SpQcNzF7279UP9".freeze
    FOLDER_MIME = "application/vnd.google-apps.folder".freeze

    EXPORT_MIME_TYPES = {
      "application/vnd.google-apps.document" => "text/plain",
      "application/vnd.google-apps.spreadsheet" => "text/csv",
      "application/vnd.google-apps.presentation" => "text/plain"
    }.freeze

    Document = Struct.new(:name, :mime_type, :content, :web_view_link, keyword_init: true)

    def initialize(user)
      @user = user
    end

    def read_by_client_and_dol(client, dol)
      match = find_match!(client, dol)
      file = resolve_to_readable_file!(match)
      download(file)
    end

    private

    attr_reader :user

    def find_match!(client, dol)
      client_name = client.to_s.strip
      sheet_dol = dol.to_s.strip

      raise NotFoundError, "Client name is missing." if client_name.blank?
      raise NotFoundError, "DOL is missing for #{client_name}." if sheet_dol.blank?

      file_dol = normalize_dol_for_filename(sheet_dol)
      tokens = client_name_tokens(client_name)
      first_name = tokens.first

      expected_names = [
        "#{client_name} (#{file_dol})",
        "#{client_name} #{file_dol}"
      ]

      match =
        expected_names.lazy.map { |name| find_by_exact_name(name) }.find(&:itself) ||
        find_best_match_by_first_name_and_dol(client_name, tokens, first_name, file_dol)

      if match.nil?
        raise NotFoundError,
              "No Drive file or folder found for \"#{first_name}\" with DOL #{file_dol}."
      end

      match
    end

    # Client folders can't be exported — open the best document inside them.
    def resolve_to_readable_file!(match)
      return match unless match.mime_type == FOLDER_MIME

      children = list_children(match.id)
      readable = children.reject { |file| file.mime_type == FOLDER_MIME }
      file = prefer_google_doc(readable)

      if file.nil?
        raise NotFoundError,
              "Found folder \"#{match.name}\" but it has no readable document inside."
      end

      file
    end

    def normalize_dol_for_filename(dol)
      parsed = parse_dol(dol)
      return pad_dol_slashes(dol) if parsed.nil?

      parsed.strftime("%m/%d/%y")
    end

    # "9/11/25" → "09/11/25" when parsing fails for any reason.
    def pad_dol_slashes(raw)
      parts = raw.to_s.strip.split("/")
      return raw unless parts.size == 3

      m, d, y = parts
      format("%02d/%02d/%s", m.to_i, d.to_i, y)
    rescue StandardError
      raw
    end

    def parse_dol(raw)
      [
        "%m/%d/%Y", "%m/%d/%y",
        "%m-%d-%Y", "%m-%d-%y",
        "%Y-%m-%d", "%Y/%m/%d"
      ].each do |fmt|
        return Date.strptime(raw, fmt)
      rescue ArgumentError
        next
      end

      # Accept unpadded "9/11/25"
      if (m = raw.to_s.strip.match(/\A(\d{1,2})\/(\d{1,2})\/(\d{2,4})\z/))
        year = m[3].length == 2 ? "20#{m[3]}".to_i : m[3].to_i
        return Date.new(year, m[1].to_i, m[2].to_i)
      end

      nil
    rescue ArgumentError
      nil
    end

    def find_by_exact_name(name)
      escaped = escape_query(name)
      response = list_in_case_folder("name = '#{escaped}'")
      Array(response.files).first
    end

    def find_best_match_by_first_name_and_dol(client_name, tokens, first_name, file_dol)
      return nil if first_name.blank?

      # Try both padded and unpadded DOL strings in the Drive query.
      dol_variants = [file_dol, unpadded_dol(file_dol)].uniq
      candidates = []

      dol_variants.each do |dol_variant|
        escaped_first = escape_query(first_name)
        escaped_dol = escape_query(dol_variant)
        response = list_in_case_folder(
          "name contains '#{escaped_first}' and name contains '#{escaped_dol}'",
          page_size: 100
        )
        candidates.concat(Array(response.files))
      end

      candidates.uniq!(&:id)

      candidates.select! do |file|
        title_includes_dol?(file.name, file_dol) &&
          name_tokens_without_dol(file.name).any? { |token| token.casecmp?(first_name) }
      end

      return nil if candidates.empty?

      scored = candidates.map do |file|
        [match_score(file, client_name, tokens, file_dol), file]
      end

      best_score, best_file = scored.max_by(&:first)
      return nil if best_score.negative?

      best_file
    end

    def unpadded_dol(file_dol)
      file_dol.to_s.gsub(%r{\b0(\d)/}, '\1/')
    end

    def match_score(file, client_name, sheet_tokens, file_dol)
      return -1 unless title_includes_dol?(file.name, file_dol)

      file_tokens = name_tokens_without_dol(file.name).map(&:downcase)
      sheet = sheet_tokens.map(&:downcase)
      return -1 if file_tokens.empty? || sheet.empty?
      return -1 unless file_tokens.include?(sheet.first)

      overlap = sheet.count { |token| file_tokens.include?(token) }
      return -1 if overlap.zero?

      exact = title_matches_name_and_dol?(file.name, client_name, file_dol) ? 10_000 : 0
      first_is_leading = file_tokens.first == sheet.first ? 500 : 0
      # Prefer opening a file directly; folders are fine but need a second lookup.
      type_bonus =
        if file.mime_type == "application/vnd.google-apps.document"
          50
        elsif file.mime_type == FOLDER_MIME
          40
        else
          0
        end
      extra_tokens = [file_tokens.size - overlap, 0].max

      exact + first_is_leading + type_bonus + (overlap * 100) - extra_tokens
    end

    def client_name_tokens(client_name)
      if client_name.include?(",")
        last, rest = client_name.split(",", 2).map(&:strip)
        first_parts = rest.to_s.split(/\s+/).reject(&:blank?)
        return normalize_tokens(first_parts + [last])
      end

      normalize_tokens(client_name.split(/\s+/))
    end

    def title_matches_name_and_dol?(file_name, client_name, file_dol)
      normalize(file_name) == normalize("#{client_name} (#{file_dol})") ||
        normalize(file_name) == normalize("#{client_name} #{file_dol}")
    end

    def title_includes_dol?(file_name, file_dol)
      normalized = normalize(file_name)
      variants = [file_dol, unpadded_dol(file_dol)].map { |dol| normalize(dol) }.uniq

      variants.any? do |dol|
        normalized.include?("(#{dol})") ||
          normalized.end_with?(" #{dol}") ||
          normalized.match?(/(?<![0-9])#{Regexp.escape(dol)}(?![0-9])/)
      end
    end

    def name_tokens_without_dol(file_name)
      base = file_name
        .sub(/\s*\(\s*\d{1,2}\/\d{1,2}\/\d{2,4}\s*\)\s*\z/, "")
        .sub(/\s+\d{1,2}\/\d{1,2}\/\d{2,4}\s*\z/, "")
        .strip

      # "Carvajalo, Lourdes Castillo" → ["Carvajalo", "Lourdes", "Castillo"]
      if base.include?(",")
        last, rest = base.split(",", 2).map(&:strip)
        return normalize_tokens(rest.to_s.split(/\s+/) + [last])
      end

      normalize_tokens(base.split(/\s+/))
    end

    def normalize_tokens(tokens)
      tokens
        .map { |token| token.to_s.gsub(/[^a-zA-Z\-']/, "") }
        .reject(&:blank?)
    end

    def normalize(value)
      value.to_s.downcase.gsub(/\s+/, " ").strip
    end

    def prefer_google_doc(files)
      list = Array(files)
      return nil if list.empty?

      list.find { |file| file.mime_type == "application/vnd.google-apps.document" } ||
        list.find { |file| EXPORT_MIME_TYPES.key?(file.mime_type) } ||
        list.first
    end

    def list_children(folder_id)
      response = drive_service.list_files(
        q: "'#{folder_id}' in parents and trashed = false",
        fields: "files(id,name,mimeType,webViewLink)",
        page_size: 50,
        supports_all_drives: true,
        include_items_from_all_drives: true,
        corpora: "allDrives"
      )
      Array(response.files)
    end

    def list_in_case_folder(query, page_size: 25)
      scoped = [
        "'#{CASE_FILES_FOLDER_ID}' in parents",
        "trashed = false",
        "(#{query})"
      ].join(" and ")

      drive_service.list_files(
        q: scoped,
        fields: "files(id,name,mimeType,webViewLink)",
        page_size: page_size,
        supports_all_drives: true,
        include_items_from_all_drives: true,
        corpora: "allDrives"
      )
    end

    def escape_query(value)
      value.to_s.gsub("'", "\\'")
    end

    def download(file)
      destination = StringIO.new
      export_mime_type = EXPORT_MIME_TYPES[file.mime_type]
      destination.set_encoding(export_mime_type ? Encoding::UTF_8 : Encoding::BINARY)

      # Read-only: export Google Docs or download binary files — never mutate Drive.
      if export_mime_type
        drive_service.export_file(file.id, export_mime_type, download_dest: destination)
      else
        drive_service.get_file(file.id, download_dest: destination)
      end

      Document.new(
        name: file.name,
        mime_type: export_mime_type || file.mime_type,
        content: destination.string,
        web_view_link: file.web_view_link
      )
    end

    def drive_service
      @drive_service ||= begin
        service = Google::Apis::DriveV3::DriveService.new
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
