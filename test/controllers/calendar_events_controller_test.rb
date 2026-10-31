require "test_helper"

class CalendarEventsControllerTest < ActionDispatch::IntegrationTest
  def reminder_for(user, title = "Scout Unit 61")
    CalendarEvent.create!(title: title, kind: "reminder", starts_on: Date.new(2026, 11, 20), user: user)
  end

  test "requires login" do
    get new_calendar_event_url
    assert_redirected_to new_user_session_path
  end

  test "new renders the form" do
    sign_in users(:alice)
    get new_calendar_event_url
    assert_response :success
    assert_select "form input[name=?]", "calendar_event[title]"
  end

  test "create saves a reminder owned by the current user" do
    sign_in users(:alice)
    assert_difference -> { users(:alice).calendar_events.count }, 1 do
      post calendar_events_url, params: { calendar_event: { title: "Buy tags", starts_on: "2026-11-20", species: "Elk" } }
    end
    assert_redirected_to calendar_path
    event = CalendarEvent.order(:id).last
    assert_equal "reminder", event.kind
    assert_equal "CO", event.state
    assert_equal users(:alice), event.user
  end

  test "create ignores attempts to set kind or user" do
    sign_in users(:alice)
    post calendar_events_url, params: { calendar_event: { title: "Sneaky", starts_on: "2026-11-20", kind: "deadline", user_id: users(:bob).id } }
    event = CalendarEvent.find_by!(title: "Sneaky")
    assert_equal "reminder", event.kind
    assert_equal users(:alice), event.user
  end

  test "create with invalid data re-renders" do
    sign_in users(:alice)
    assert_no_difference -> { CalendarEvent.count } do
      post calendar_events_url, params: { calendar_event: { title: "", starts_on: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "update changes own reminder" do
    event = reminder_for(users(:alice))
    sign_in users(:alice)
    patch calendar_event_url(event), params: { calendar_event: { title: "Renamed" } }
    assert_redirected_to calendar_path
    assert_equal "Renamed", event.reload.title
  end

  test "cannot edit, update or delete someone else's reminder" do
    event = reminder_for(users(:bob))
    sign_in users(:alice)
    assert_raises(ActiveRecord::RecordNotFound) { get edit_calendar_event_url(event) }
    sign_in users(:alice) # a raised exception drops the Warden test login
    assert_raises(ActiveRecord::RecordNotFound) { patch calendar_event_url(event), params: { calendar_event: { title: "Hijack" } } }
    sign_in users(:alice)
    assert_raises(ActiveRecord::RecordNotFound) { delete calendar_event_url(event) }
    assert_equal "Scout Unit 61", event.reload.title
  end

  test "cannot touch public events" do
    public_event = CalendarEvent.create!(title: "Deadline", kind: "deadline", starts_on: Date.new(2027, 4, 6))
    sign_in users(:alice)
    assert_raises(ActiveRecord::RecordNotFound) { delete calendar_event_url(public_event) }
    assert CalendarEvent.exists?(public_event.id)
  end

  test "destroy removes own reminder" do
    event = reminder_for(users(:alice))
    sign_in users(:alice)
    assert_difference -> { CalendarEvent.count }, -1 do
      delete calendar_event_url(event)
    end
    assert_redirected_to calendar_path
  end

  test "own reminders show edit and delete controls on the calendar page" do
    event = reminder_for(users(:alice))
    sign_in users(:alice)
    get calendar_url
    assert_select "a[href=?]", edit_calendar_event_path(event)
    assert_select "form[action=?]", calendar_event_path(event)
  end
end
