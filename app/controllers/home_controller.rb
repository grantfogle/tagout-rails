class HomeController < ApplicationController
  # Signed-out visitors get the marketing page; signed-in users get their personal home.
  def index
    return unless user_signed_in?

    @profile = current_user.profile
    @upcoming_events = CalendarService.new(current_user).upcoming
    render :personal
  end
end
