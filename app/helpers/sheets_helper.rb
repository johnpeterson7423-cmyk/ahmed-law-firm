module SheetsHelper
  COLUMN_LABELS = Google::SheetsService::HEADER_LABELS

  def column_label(column)
    COLUMN_LABELS[column] || column.to_s.humanize
  end

  def next_sort_direction(column)
    if params[:sort] == column && params[:direction] != "desc"
      "desc"
    else
      "asc"
    end
  end

  def sort_indicator(column)
    return "" unless params[:sort] == column

    params[:direction] == "desc" ? " ↓" : " ↑"
  end

  def filter_query_params(extra = {})
    {
      query: params[:query],
      country: params[:country],
      status: params[:status],
      sort: params[:sort],
      direction: params[:direction]
    }.merge(extra).compact_blank
  end

  def active_filters?
    params[:query].present? || params[:country].present? || params[:status].present?
  end

  def status_badge_class(status)
    case status.to_s.downcase
    when "active" then "badge badge--active"
    when "pending" then "badge badge--pending"
    else "badge badge--inactive"
    end
  end

  def format_cell(column, value)
    return "" if value.blank?

    case column
    when "salary"
      number_with_delimiter(value.to_s.gsub(/[^\d]/, "").to_i)
    when "phone"
      value.to_s
    else
      value.to_s
    end
  end
end
