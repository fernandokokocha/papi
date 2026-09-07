class PagesController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  layout "public"

  def landing; end

  def about; end
end
