module CalendarHelper
  def event_date_label(event)
    start = event.starts_on.strftime("%b %-d")
    return start if event.ends_on.blank? || event.ends_on == event.starts_on

    "#{start} – #{event.ends_on.strftime('%b %-d')}"
  end

  def event_kind_label(event)
    CalendarEvent::KIND_LABELS.fetch(event.kind, event.kind.to_s.humanize)
  end
end
