require "test_helper"
require "tmpdir"

class CalendarLoaderTest < ActiveSupport::TestCase
  def write_yaml(dir, body)
    path = File.join(dir, "test.yml")
    File.write(path, body)
    path
  end

  BASIC = <<~YAML
    events:
      - title: Application deadline
        kind: deadline
        starts_on: 2027-04-06
      - title: Elk archery season
        kind: season
        species: Elk
        starts_on: 2026-09-02
        ends_on: 2026-09-30
  YAML

  test "loads events, defaulting state to CO" do
    Dir.mktmpdir do |dir|
      assert_equal 2, CalendarLoader.call([write_yaml(dir, BASIC)])
    end

    deadline = CalendarEvent.find_by!(title: "Application deadline")
    assert_equal "CO", deadline.state
    assert_nil deadline.user_id
    assert_nil deadline.species
    assert_equal Date.new(2026, 9, 30), CalendarEvent.find_by!(title: "Elk archery season").ends_on
  end

  test "is idempotent and updates changed rows instead of duplicating" do
    Dir.mktmpdir do |dir|
      path = write_yaml(dir, BASIC)
      CalendarLoader.call([path])
      CalendarLoader.call([path])
      assert_equal 2, CalendarEvent.count

      File.write(path, BASIC.sub("ends_on: 2026-09-30", "ends_on: 2026-10-01"))
      CalendarLoader.call([path])
      assert_equal 2, CalendarEvent.count
      assert_equal Date.new(2026, 10, 1), CalendarEvent.find_by!(title: "Elk archery season").ends_on
    end
  end

  test "raises on an invalid row" do
    Dir.mktmpdir do |dir|
      bad = write_yaml(dir, "events:\n  - title: Oops\n    kind: party\n    starts_on: 2026-11-01\n")
      assert_raises(ActiveRecord::RecordInvalid) { CalendarLoader.call([bad]) }
    end
  end
end
