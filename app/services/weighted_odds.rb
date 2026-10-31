# Projected odds for a weighted draw.
#
# Every applicant gets a random score in [0, 1], divided by (weighted points + 1);
# the lowest scores win. For a pool described by `levels` ({ weighted_points =>
# applicants }) and `awarded` licenses, a cutoff score t exists where the expected
# number of winners equals `awarded`. An applicant at weight w then draws with
# probability min(1, t * (w + 1)). This is the expected-value form of the draw, so
# it smooths out the luck of a single year's results.
class WeightedOdds
  def initialize(levels, awarded)
    @levels = levels.select { |_, applicants| applicants.to_i > 0 }.transform_values(&:to_i)
    @awarded = awarded.to_i
  end

  # { weighted_points => probability between 0.0 and 1.0 }
  def odds
    return {} if @levels.empty?
    return @levels.transform_values { 0.0 } if @awarded <= 0
    return @levels.transform_values { 1.0 } if @awarded >= @levels.values.sum

    t = cutoff
    @levels.to_h { |w, _| [w, [t * (w + 1), 1.0].min] }
  end

  private

  # Highest factors saturate first, so try saturating 0, 1, 2... of them until the
  # resulting cutoff no longer pushes the next level past 100%.
  def cutoff
    by_factor = @levels.map { |w, n| [w + 1, n] }.sort_by { |factor, _| -factor }

    (0...by_factor.size).each do |saturated|
      taken = by_factor.first(saturated).sum { |_, n| n }
      open = by_factor.drop(saturated)
      t = (@awarded - taken).to_f / open.sum { |factor, n| factor * n }
      return t if t * open.first[0] <= 1.0
    end
  end
end
