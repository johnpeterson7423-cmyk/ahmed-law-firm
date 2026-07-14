class SheetsController < ApplicationController
  before_action :require_user

  PER_PAGE = 10

  def index
    service = Google::SheetsService.new(current_user)
    service.refresh! if params[:refresh].present?

    @columns = Google::SheetsService::HEADERS
    @column_labels = Google::SheetsService::HEADER_LABELS
    @all_users = service.users
    @countries = service.countries
    @statuses = service.statuses
    @per_page = PER_PAGE

    @filtered_users = service.filter_users(
      query: params[:query],
      country: params[:country],
      status: params[:status]
    )

    sort_users
    @total_count = @filtered_users.size
    paginate_users
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
    redirect_to root_path, alert: "Google authorization expired. Please sign in again."
  rescue Google::Apis::ClientError, Google::Apis::ServerError => e
    redirect_to root_path, alert: "Could not load sheet data: #{e.message}"
  end

  def export
    service = Google::SheetsService.new(current_user)

    rows = service.filter_users(
      query: params[:query],
      country: params[:country],
      status: params[:status]
    )

    if params[:sort].present?
      rows = sort_rows(rows, params[:sort], params[:direction])
    end

    if rows.empty?
      redirect_to sheets_path(filter_params), alert: "No rows to export with the current filters."
      return
    end

    csv = service.to_csv(rows)
    filename = "sheetflow-export-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"

    send_data csv,
              filename: filename,
              type: "text/csv; charset=utf-8",
              disposition: "attachment"
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
    redirect_to root_path, alert: "Google authorization expired. Please sign in again."
  rescue Google::Apis::ClientError, Google::Apis::ServerError => e
    redirect_to sheets_path(filter_params), alert: "Export failed: #{e.message}"
  end

  private

  def sort_users
    return unless params[:sort].present?

    @filtered_users = sort_rows(@filtered_users, params[:sort], params[:direction])
  end

  def sort_rows(rows, column, direction)
    dir = direction == "desc" ? -1 : 1
    numeric = %w[id age salary].include?(column)

    rows.sort do |a, b|
      left = a[column]
      right = b[column]

      comparison =
        if numeric
          left.to_s.gsub(/[^\d.-]/, "").to_f <=> right.to_s.gsub(/[^\d.-]/, "").to_f
        else
          left.to_s <=> right.to_s
        end

      comparison * dir
    end
  end

  def paginate_users
    @page = params[:page].to_i
    @page = 1 if @page < 1

    @total_pages = [(@total_count.to_f / PER_PAGE).ceil, 1].max
    @page = @total_pages if @page > @total_pages

    start_index = (@page - 1) * PER_PAGE
    @users = @filtered_users.slice(start_index, PER_PAGE) || []
  end

  def filter_params
    params.permit(:query, :country, :status, :sort, :direction, :page).to_h
  end
end
