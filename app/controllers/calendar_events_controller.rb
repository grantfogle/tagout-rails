class CalendarEventsController < ApplicationController
  before_action :authenticate_user!
  # Scoped to the current user, so other people's reminders and all public
  # events raise RecordNotFound (404).
  before_action :set_event, only: [:edit, :update, :destroy]

  def new
    @event = current_user.calendar_events.build(starts_on: Date.current)
  end

  def create
    @event = current_user.calendar_events.build(event_params.merge(kind: "reminder", state: "CO"))
    if @event.save
      redirect_to calendar_path, notice: "Reminder added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @event.update(event_params)
      redirect_to calendar_path, notice: "Reminder updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to calendar_path, notice: "Reminder deleted."
  end

  private

  def set_event
    @event = current_user.calendar_events.find(params[:id])
  end

  def event_params
    params.require(:calendar_event).permit(:title, :species, :starts_on, :ends_on, :notes)
  end
end
