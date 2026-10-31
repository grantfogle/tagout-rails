class CalendarService
  def initialize(user, today: Date.current)
    @user = user
    @today = today
  end

  # Events from today through `days` days out, soonest first.
  def upcoming(days: 30)
    scoped(nil).between(@today, @today + days).chronological
  end

  # The next 12 months as { first_of_month => [events] }. An event is filed under
  # the month it starts in, or the current month if it started earlier (a season
  # already underway).
  def year(species: nil, mine_only: false)
    months = Array.new(12) { |i| @today.beginning_of_month >> i }
    events = scoped(species).between(@today, months.last.end_of_month).chronological
    events = events.where(user_id: @user.id) if mine_only

    buckets = months.index_with { [] }
    events.each { |event| buckets[[event.starts_on, @today].max.beginning_of_month] << event }
    buckets
  end

  private

  def scoped(explicit_species)
    CalendarEvent.visible_to(@user).for_species(species_list(explicit_species))
  end

  def species_list(explicit)
    return [explicit] if explicit.present?

    @user.profile&.favorite_species.presence
  end
end
