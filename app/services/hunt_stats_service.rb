class HuntStatsService
  DEFAULT_LIMIT_PER_CODE = 50
  DEFAULT_PAGE_SIZE = 20

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

    # Get unique hunt codes with pagination
    all_hunt_codes = q.select(:hunt_code).distinct.order(:hunt_code).pluck(:hunt_code)
    total_codes = all_hunt_codes.count
    
    offset = (page - 1) * per_page
    paginated_codes = all_hunt_codes.slice(offset, per_page) || []
    
    return { results: {}, has_more: false, next_page: nil, total_count: 0 } if paginated_codes.empty?

    # Fetch data only for the paginated hunt codes
    rows = q
      .where(hunt_code: paginated_codes)
      .select(:hunt_code, :value, :resident, :adult, :draw_type, :applicants, :success)
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
      
      result[hunt_code] = {
        max_points: max_points,
        resident: build_residency_data(pref_records.select(&:resident), choice_records.select(&:resident)),
        nonresident: build_residency_data(pref_records.reject(&:resident), choice_records.reject(&:resident))
      }
    end
    
    has_more = (offset + per_page) < total_codes
    
    {
      results: result,
      has_more: has_more,
      next_page: has_more ? page + 1 : nil,
      total_count: total_codes
    }
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

  def apply_filters(q, filters)
    q = q.where(state: filters[:state]) if filters[:state].present?
    q = q.where(hunt_code: filters[:hunt_code]) if filters[:hunt_code].present?
    q = q.where(species: filters[:species]) if filters[:species].present?
    q = q.where(sex: filters[:sex]) if filters[:sex].present?
    q = q.where(hunt_method: filters[:hunt_method]) if filters[:hunt_method].present?

    q = q.where(resident: filters[:resident]) unless filters[:resident].nil?
    q = q.where(adult: filters[:adult]) unless filters[:adult].nil?
    q = q.where(draw_type: filters[:draw_type]) if filters[:draw_type].present?

    q
  end
end
