class HuntStatsService
  DEFAULT_LIMIT_PER_CODE = 50

  def initialize(scope: HuntStat.all)
    @scope = scope
  end

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
