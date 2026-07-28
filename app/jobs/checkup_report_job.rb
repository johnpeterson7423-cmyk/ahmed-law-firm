class CheckupReportJob < ApplicationJob
  queue_as :default

  def perform(checkup_run_id)
    run = CheckupRun.find(checkup_run_id)
    Google::CheckupReportService.new(run).call
  end
end
