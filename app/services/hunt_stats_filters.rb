class HuntStatsFilters
  KEYS = %i[hunt_code state species sex hunt_method season resident adult draw_type units points odds].freeze

  # Whitelists and normalizes raw filter params (ActionController::Parameters or Hash)
  # into the symbol-keyed hash HuntStatsService expects.
  def self.parse(raw)
    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    return {} unless raw.is_a?(Hash)

    filters = raw.with_indifferent_access.slice(*KEYS).to_h.symbolize_keys
    filters[:resident] = cast_bool(filters[:resident])
    filters[:adult]    = cast_bool(filters[:adult])

    units = parse_units(filters[:units])
    units.empty? ? filters.delete(:units) : filters[:units] = units

    # Not a DB filter: the preference-points column to highlight in the table.
    points = Integer(filters[:points].to_s.strip, 10, exception: false)
    points && points.between?(0, 99) ? filters[:points] = points : filters.delete(:points)

    # Minimum draw odds (%); 0 means no odds filtering.
    odds = Integer(filters[:odds].to_s.strip, 10, exception: false)
    odds && odds.between?(1, 100) ? filters[:odds] = odds : filters.delete(:odds)
    filters
  end

  # Accepts "11,43" or ["11", "43"]; units are stored as zero-padded 3-digit strings ("011").
  def self.parse_units(val)
    list = val.is_a?(String) ? val.split(",") : Array(val)
    list.map { |u| u.to_s.strip }.grep(/\A\d{1,3}\z/).map { |u| u.rjust(3, "0") }.uniq
  end

  def self.cast_bool(val)
    case val.to_s.downcase
    when "true"  then true
    when "false" then false
    end
  end
  private_class_method :cast_bool
end
