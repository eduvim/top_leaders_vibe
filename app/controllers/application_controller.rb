class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # RF-05: a storage failure surfaces as an error screen and never
  # claims an entry was logged.
  rescue_from EntryRepository::StorageError do
    render "errors/storage_unavailable", status: :service_unavailable
  end
end
