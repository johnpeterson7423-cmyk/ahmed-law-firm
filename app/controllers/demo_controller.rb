class DemoController < ApplicationController
  MAX_FILE_SIZE = 5.megabytes

  def new
    redirect_to sheets_path if current_user || demo_active?
  end

  def create
    file = params[:file]

    if file.blank?
      redirect_to new_demo_path, alert: "Choose an Excel (.xlsx) file to upload." and return
    end

    if file.size > MAX_FILE_SIZE
      redirect_to new_demo_path, alert: "File is too large (max 5MB)." and return
    end

    ext = File.extname(file.original_filename.to_s).delete_prefix(".").downcase
    unless Demo::RosterFileService::EXTENSIONS.include?(ext)
      redirect_to new_demo_path, alert: "Unsupported file type — upload a .xlsx file." and return
    end

    token = SecureRandom.hex(16)
    FileUtils.mkdir_p(DEMO_UPLOADS_DIR)
    path = DEMO_UPLOADS_DIR.join("#{token}.#{ext}")
    File.binwrite(path, file.read)

    begin
      Demo::RosterFileService.new(path).users
    rescue Demo::RosterFileService::ParseError
      File.delete(path)
      redirect_to new_demo_path, alert: "Couldn't read that file. Make sure it's a valid Excel file with a header row." and return
    end

    session[:demo_token] = token
    session[:demo_ext] = ext

    redirect_to sheets_path, notice: "Demo data loaded from #{file.original_filename}."
  end

  def destroy
    clear_demo!
    redirect_to root_path, notice: "Demo data cleared."
  end
end
