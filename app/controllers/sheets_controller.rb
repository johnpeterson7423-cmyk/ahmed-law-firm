class SheetsController < ApplicationController
  before_action :require_access

  PER_PAGE = 10

  def index
    service = roster_service

    @columns = RosterTable::HEADERS
    @insurances = service.insurances
    @statuses = service.statuses
    @filtered_users = service.filter_users(
      query: params[:query],
      insurance: params[:insurance],
      status: params[:status]
    )

    # Sheet is filled top→bottom; show newest (bottom) rows first by default.
    if params[:sort].present?
      sort_users
    else
      @filtered_users = @filtered_users.reverse
    end

    @total_count = @filtered_users.size
    paginate_users
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
    redirect_to root_path, alert: "Google authorization expired. Please sign in again."
  rescue Google::Apis::ClientError, Google::Apis::ServerError => e
    redirect_to root_path, alert: "Could not load sheet data: #{e.message}"
  rescue Demo::RosterFileService::ParseError
    clear_demo!
    redirect_to root_path, alert: "Your demo file could not be read. Please upload it again."
  end

  def document
    if demo_mode?
      redirect_to sheets_path, alert: "Case files aren't available in demo mode. Sign in with Google to view them."
      return
    end

    @client = params[:client]
    @dol = params[:dol]
    document = Google::DriveService.new(current_user).read_by_client_and_dol(@client, @dol)
    @document_name = document.name
    @mime_type = document.mime_type
    @content = document.content
    @web_view_link = document.web_view_link
  rescue Google::DriveService::NotFoundError => e
    redirect_to sheets_path, alert: e.message
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
    redirect_to root_path, alert: "Google authorization expired. Please sign in again."
  rescue Google::Apis::ClientError, Google::Apis::ServerError => e
    redirect_to sheets_path, alert: "Could not load document: #{e.message}"
  end

  def checkup_report
    if demo_mode?
      redirect_to sheets_path, alert: "Checkup bot requires Google sign-in."
      return
    end

    prepare_checkup_form
    @run = current_user.checkup_runs.recent_first.first
    paginate_checkup_results
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
    redirect_to root_path, alert: "Google authorization expired. Please sign in again."
  rescue Google::Apis::ClientError, Google::Apis::ServerError => e
    redirect_to sheets_path, alert: "Could not load sheet data: #{e.message}"
  end

  def run_checkup_report
    if demo_mode?
      redirect_to sheets_path, alert: "Checkup bot requires Google sign-in."
      return
    end

    prepare_checkup_form
    limit = [[@limit.to_i, 1].max, Google::CheckupReportService::MAX_LIMIT].min
    clients = @eligible_clients.first(limit).map { |row| row.slice("clients", "dol") }

    if current_user.checkup_runs.where(status: %w[pending running]).exists?
      redirect_to checkup_report_sheets_path, alert: "A checkup bot run is already in progress."
      return
    end

    run = current_user.checkup_runs.create!(
      status: "pending",
      limit_count: limit,
      total: clients.size,
      query: params[:query],
      clients_payload: clients
    )

    CheckupReportJob.perform_later(run.id)

    redirect_to checkup_report_sheets_path(
      query: params[:query],
      limit: limit,
      needs_call: params[:needs_call],
      status: params[:status]
    ), notice: "Bot started in the background — saving results to the database (run ##{run.id})."
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
    redirect_to root_path, alert: "Google authorization expired. Please sign in again."
  rescue Google::Apis::ClientError, Google::Apis::ServerError, StandardError => e
    redirect_to checkup_report_sheets_path, alert: "Checkup bot failed: #{e.message}"
  end

  private

  def prepare_checkup_form
    service = roster_service
    @eligible_clients = service.filter_users(query: params[:query]).reverse
    @eligible_count = @eligible_clients.size
    @limit = params[:limit].presence || Google::CheckupReportService::DEFAULT_LIMIT
  end

  def roster_service
    @roster_service ||= if demo_mode?
      Demo::RosterFileService.new(demo_file_path)
    else
      Google::SheetsService.new(current_user)
    end
  end

  def sort_users
    return unless params[:sort].present?

    @filtered_users = sort_rows(@filtered_users, params[:sort], params[:direction])
  end

  def sort_rows(rows, column, direction)
    dir = direction == "desc" ? -1 : 1

    rows.sort do |a, b|
      (a[column].to_s <=> b[column].to_s) * dir
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

  def paginate_checkup_results
    @results = []
    @results_total = 0
    @page = 1
    @total_pages = 1
    @per_page = PER_PAGE
    return unless @run

    scope = @run.checkup_results.order(id: :desc)
    scope = scope.where(needs_to_call: true) if params[:needs_call] == "yes"
    scope = scope.where(needs_to_call: false) if params[:needs_call] == "no"
    scope = scope.where(status: params[:status]) if %w[found not_found].include?(params[:status])

    @results_total = scope.count
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @total_pages = [(@results_total.to_f / @per_page).ceil, 1].max
    @page = @total_pages if @page > @total_pages && @results_total.positive?

    @results = scope.offset((@page - 1) * @per_page).limit(@per_page)
  end
end
