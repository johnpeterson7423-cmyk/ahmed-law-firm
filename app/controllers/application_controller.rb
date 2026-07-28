class ApplicationController < ActionController::Base

  helper_method :current_user, :demo_mode?


  def current_user
    @current_user ||= User.find_by(
      id: session[:user_id]
    )
  end

  # True once a Google account is connected or demo file data is active.
  def demo_mode?
    !current_user && demo_active?
  end

  def demo_active?
    session[:demo_token].present? && session[:demo_ext].present? && demo_file_path.exist?
  end

  DEMO_UPLOADS_DIR = Rails.root.join("tmp", "demo_uploads")

  def demo_file_path
    token = session[:demo_token].to_s[/\A[a-f0-9]+\z/]
    ext = session[:demo_ext].to_s[/\A(?:#{Demo::RosterFileService::EXTENSIONS.join('|')})\z/]
    return DEMO_UPLOADS_DIR.join("_none_") unless token && ext

    DEMO_UPLOADS_DIR.join("#{token}.#{ext}")
  end

  def require_access
    redirect_to root_path, alert: "Please sign in with Google or upload a file to continue." unless current_user || demo_active?
  end

  def clear_demo!
    File.delete(demo_file_path) if demo_active?
    session.delete(:demo_token)
    session.delete(:demo_ext)
  end

end
