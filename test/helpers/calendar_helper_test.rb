require "test_helper"

class CalendarHelperTest < ActionView::TestCase
  test "single-day events show one date" do
    event = CalendarEvent.new(starts_on: Date.new(2026, 11, 3))
    assert_equal "Nov 3", event_date_label(event)
  end

  test "ranges show both ends" do
    event = CalendarEvent.new(starts_on: Date.new(2026, 11, 3), ends_on: Date.new(2026, 11, 9))
    assert_equal "Nov 3 – Nov 9", event_date_label(event)
  end

  test "kind label is human readable" do
    assert_equal "Draw results", event_kind_label(CalendarEvent.new(kind: "draw_results"))
  end
end
