class PostsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  layout "public"

  def index
    @posts = Blog::Post.all
  end

  def show
    @post = Blog::Post.find(params[:slug])
  end
end
