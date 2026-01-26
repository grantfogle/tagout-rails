class FeedbacksController < ApplicationController
  def create
    @feedback = Feedback.new(feedback_params)

    if @feedback.save
      redirect_back fallback_location: dashboard_path, notice: "Thanks for your feedback!"
    else
      redirect_back fallback_location: dashboard_path, alert: "Please add a comment."
    end
  end

  private

  def feedback_params
    params.permit(:email, :comment)
  end
end
