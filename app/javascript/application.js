// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

// Drive stays off: it breaks the sidebar anchor highlight (fa567a8).
// Forms opt in per-element with data-turbo="true".
Turbo.session.drive = false
