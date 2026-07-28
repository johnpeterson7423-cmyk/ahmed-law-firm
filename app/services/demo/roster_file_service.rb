require "roo"

module Demo
  class RosterFileService
    HEADERS = RosterTable::HEADERS
    HEADER_LABELS = RosterTable::HEADER_LABELS
    EXTENSIONS = %w[xlsx].freeze

    ParseError = Class.new(StandardError)

    def initialize(file_path)
      @file_path = Pathname.new(file_path)
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

    def table
      @table ||= RosterTable.new(parsed_rows)
    end

    def parsed_rows
      spreadsheet = Roo::Excelx.new(@file_path.to_s)
      sheet = spreadsheet.sheet(spreadsheet.sheets.first)

      (sheet.first_row..sheet.last_row).map do |i|
        sheet.row(i).map(&:to_s)
      end
    rescue StandardError => e
      raise ParseError, e.message
    end
  end
end
