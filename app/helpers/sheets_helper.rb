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
      insurance: params[:insurance],
      status: params[:status],
      needs_call: params[:needs_call],
      sort: params[:sort],
      direction: params[:direction],
      limit: params[:limit],
      page: params[:page]
    }.merge(extra).compact_blank
  end

  def checkup_filter_params(extra = {})
    {
      query: params[:query],
      needs_call: params[:needs_call],
      status: params[:status],
      limit: params[:limit],
      page: params[:page]
    }.merge(extra).compact_blank
  end

  def active_filters?
    params[:query].present? || params[:insurance].present? || params[:status].present?
  end

  # Windowed page list, e.g. [1, :gap, 4, 5, 6, 7, 8, :gap, 42]
  def pagination_items(current, total, edge: 1, around: 2)
    return (1..total).to_a if total <= (edge * 2) + (around * 2) + 3

    pages = (1..total).select do |p|
      p <= edge || p > total - edge || (p - current).abs <= around
    end

    pages.each_with_object([]) do |page, items|
      items << :gap if items.last.is_a?(Integer) && page - items.last > 1
      items << page
    end
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

    value.to_s
  end
end
