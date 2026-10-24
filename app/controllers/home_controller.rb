class HomeController < ApplicationController
  # Signed-out visitors get the marketing page; signed-in users get their personal home.
  def index
    return unless user_signed_in?

    @profile = current_user.profile
    render :personal
  end
end
