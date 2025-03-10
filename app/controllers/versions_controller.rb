class VersionsController < ApplicationController
  def show
    # debugger
    @version = Version.find(params[:id])
    @previous_version = @version.previous
    @next_version = @version.next
  end
end
