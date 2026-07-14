// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "bootstrap"

// Faster progress-bar feedback during Turbo Drive navigation
if (window.Turbo?.config?.drive) {
  Turbo.config.drive.progressBarDelay = 50
}
