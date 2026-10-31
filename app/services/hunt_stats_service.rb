class HuntStatsService
  DEFAULT_LIMIT_PER_CODE = 50
  DEFAULT_PAGE_SIZE = 20
  WEIGHTED_ELIGIBLE_POINTS = 3  # preference points needed to enter a weighted draw
  SMALL_SAMPLE = 10             # fewer applicants than this makes a level's odds unreliable

  def initialize(scope: HuntStat.all)
    @scope = scope
  end

  # Returns draw results structured for display with pagination info:
  # {
  #   results: { "EE001E1R" => { max_points: 30, resident: {...}, nonresident: {...} }, ... },
  #   has_more: true/false,
  #   next_page: 2
  # }
  def draw_results_by_code(filters: {}, page: 1, per_page: DEFAULT_PAGE_SIZE)
    q = apply_filters(@scope, filters)

    # Get the global max points across ALL filtered data (for consistent column count)
    global_max_points = q.where(draw_type: "pref").maximum(:value) || 0

    # Get unique hunt codes with pagination
    all_hunt_codes = apply_min_odds(q, filters).select(:hunt_code).distinct.order(:hunt_code).pluck(:hunt_code)
    total_codes = all_hunt_codes.count
    
    offset = (page - 1) * per_page
    paginated_codes = all_hunt_codes.slice(offset, per_page) || []
    
    return { results: {}, has_more: false, next_page: nil, total_count: 0, global_max_points: global_max_points } if paginated_codes.empty?

    # Fetch data only for the paginated hunt codes
    rows = q
      .where(hunt_code: paginated_codes)
      .select(:hunt_code, :unit, :value, :resident, :adult, :draw_type, :applicants, :success)
      .order(hunt_code: :asc, value: :desc)
      .to_a

    grouped = rows.group_by(&:hunt_code)
    
    result = {}
    
    # Maintain order from paginated_codes
    paginated_codes.each do |hunt_code|
      records = grouped[hunt_code] || []
      pref_records = records.select { |r| r.draw_type == "pref" }
      choice_records = records.select { |r| r.draw_type == "total_choice" }
      
      max_points = pref_records.map(&:value).max || 0
      unit = records.first&.unit
      
      result[hunt_code] = {
        max_points: max_points,
        unit: unit,
        resident: build_residency_data(pref_records.select(&:resident), choice_records.select(&:resident)),
        nonresident: build_residency_data(pref_records.reject(&:resident), choice_records.reject(&:resident))
      }
    end
    
    has_more = (offset + per_page) < total_codes
    
    {
      results: result,
      has_more: has_more,
      next_page: has_more ? page + 1 : nil,
      total_count: total_codes,
      global_max_points: global_max_points
    }
  end

  # Weighted-draw detail for the given hunt codes:
  # { "SMS01O1R" => { resident: { under_three: {...}, levels: { weighted_points => {...} } }, nonresident: {...} } }
  # Applicants with fewer than 3 preference points are one actuals-only cell. Everyone
  # else is split by weighted level, each with actual results and projected odds (see
  # WeightedOdds) computed from that pool and the licenses actually awarded.
  def weighted_results(hunt_codes)
    WeightedStat.where(hunt_code: hunt_codes, adult: true).group_by(&:hunt_code).transform_values do |rows|
      { resident: weighted_pool(rows.select(&:resident)), nonresident: weighted_pool(rows.reject(&:resident)) }
    end
  end

  # Widest weighted level for a species, so table columns stay consistent across pages.
  def max_weighted_points(species)
    WeightedStat.where(hunt_code: @scope.where(species: species).select(:hunt_code)).maximum(:weighted_points) || 0
  end

  # Legacy method for backwards compatibility
  def grouped_draw_results(limit_per_code: DEFAULT_LIMIT_PER_CODE, filters: {})
    q = apply_filters(@scope, filters)

    rows = q
      .select(:hunt_code, :value, :resident, :adult, :draw_type, :applicants, :success)
      .order(hunt_code: :asc, value: :desc, resident: :desc, adult: :desc, draw_type: :asc)
      .to_a

    grouped = rows.group_by(&:hunt_code)

    grouped.transform_values do |arr|
      arr.first(limit_per_code).map do |r|
        {
          value: r.value,
          resident: r.resident,
          adult: r.adult,
          draw_type: r.draw_type,
          applicants: r.applicants,
          success: r.success,
        }
      end
    end
  end

  private

  def weighted_pool(rows)
    eligible, under = rows.partition { |r| r.preference_points >= WEIGHTED_ELIGIBLE_POINTS }
    applicants = eligible.group_by(&:weighted_points).transform_values { |rs| rs.sum(&:applicants) }
    projected = WeightedOdds.new(applicants, eligible.sum(&:success)).odds

    levels = eligible.group_by(&:weighted_points).to_h do |weighted, rs|
      n = rs.sum(&:applicants)
      won = rs.sum(&:success)
      [weighted, {
        applicants: n,
        success: won,
        actual: n > 0 ? (won.to_f / n * 100).round(1) : nil,
        projected: projected[weighted] && (projected[weighted] * 100).round(1),
        sparse: n < SMALL_SAMPLE
      }]
    end

    n = under.sum(&:applicants)
    won = under.sum(&:success)
    { under_three: { applicants: n, success: won, actual: n > 0 ? (won.to_f / n * 100).round(1) : nil, projected: nil },
      levels: levels.sort.to_h }
  end

  def build_residency_data(pref_records, choice_records)
    pref_data = {}
    choice_data = {}
    
    # Build preference point data (descending order)
    pref_records.sort_by { |r| -r.value }.each do |r|
      odds = r.applicants > 0 ? (r.success.to_f / r.applicants * 100).round(1) : nil
      pref_data[r.value] = {
        applicants: r.applicants,
        success: r.success,
        odds: odds
      }
    end
    
    # Build choice data (2nd, 3rd, 4th choice)
    choice_records.each do |r|
      next if r.value == 1 # Skip 1st choice as that's the primary preference draw
      odds = r.applicants > 0 ? (r.success.to_f / r.applicants * 100).round(1) : nil
      choice_data[r.value] = {
        applicants: r.applicants,
        success: r.success,
        odds: odds
      }
    end
    
    { pref: pref_data, choice: choice_data }
  end

  # Keeps only hunt codes that have at least one draw with odds >= filters[:odds]. Whole codes are
  # kept (not just the matching rows) so their other columns still display. If a preference-points
  # column is chosen, only that column's odds are considered.
  def apply_min_odds(q, filters)
    min_odds = filters[:odds]
    return q unless min_odds.present? && min_odds.positive?

    matching = q.where("hunt_stats.applicants > 0 AND hunt_stats.success * 100.0 / hunt_stats.applicants >= ?", min_odds)
    matching = matching.where(draw_type: "pref", value: filters[:points]) if filters[:points]
    q.where(hunt_code: matching.select(:hunt_code))
  end

  def apply_filters(q, filters)
    q = q.where(state: filters[:state]) if filters[:state].present?
    q = q.where(hunt_code: filters[:hunt_code]) if filters[:hunt_code].present?
    q = q.where(species: filters[:species]) if filters[:species].present?
    q = q.where(sex: filters[:sex]) if filters[:sex].present?
    q = q.where(hunt_method: filters[:hunt_method]) if filters[:hunt_method].present?
    q = q.where(season: filters[:season]) if filters[:season].present?
    q = q.where(unit: filters[:units]) if filters[:units].present?

    q = q.where(resident: filters[:resident]) unless filters[:resident].nil?
    q = q.where(adult: filters[:adult]) unless filters[:adult].nil?
    q = q.where(draw_type: filters[:draw_type]) if filters[:draw_type].present?

    q
  end
end
