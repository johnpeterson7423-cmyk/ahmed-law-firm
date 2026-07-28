class RosterTable
  HEADERS = %w[
    clients dol dob phone_number insurance policy_limits liability
    nf_wc_info_claim_number wc_attorney referred_by body_parts
    treatment_location treatment_status
  ].freeze

  HEADER_LABELS = {
    "clients" => "Client",
    "dol" => "DOL",
    "dob" => "DOB",
    "phone_number" => "Phone Number",
    "insurance" => "Insurance",
    "policy_limits" => "Policy Limits",
    "liability" => "Liability",
    "nf_wc_info_claim_number" => "NF/WC Info (Claim Number)",
    "wc_attorney" => "WC Attorney",
    "referred_by" => "Referred By",
    "body_parts" => "Body Parts",
    "treatment_location" => "Treatment Location",
    "treatment_status" => "Treatment Status"
  }.freeze

  # rows: array of arrays, header row first (as returned from a sheet/Excel read).
  def initialize(rows)
    @rows = rows || []
  end

  def users
    return @users if defined?(@users)

    rows = @rows.dup
    if rows.blank?
      @users = []
      return @users
    end

    headers = rows.shift.map { |h| normalize_header(h) }

    @users = rows.map do |row|
      padded = row + Array.new([headers.size - row.size, 0].max, "")
      headers.zip(padded.first(headers.size)).to_h
    end
  end

  def filter_users(query: nil, insurance: nil, status: nil)
    result = users

    if query.present?
      q = query.to_s.strip
      pattern = /\b#{Regexp.escape(q)}/i
      result = result.select do |row|
        row.values.any? { |value| value.to_s.match?(pattern) }
      end
    end

    if insurance.present?
      result = result.select { |row| row["insurance"].to_s.strip.casecmp?(insurance.to_s.strip) }
    end

    if status.present?
      result = result.select { |row| row["treatment_status"].to_s.downcase == status.to_s.downcase }
    end

    result
  end

  def insurances
    dedupe_names(users.map { |row| row["insurance"].to_s })
  end

  def statuses
    dedupe_names(users.map { |row| row["treatment_status"].to_s })
  end

  private

  def dedupe_names(values)
    values
      .map { |value| value.strip }
      .reject(&:blank?)
      .group_by(&:downcase)
      .map { |_key, group| group.first }
      .sort
  end

  def normalize_header(header)
    header.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
  end
end
