class DashboardController < ApplicationController
  before_action :authenticate_user!
  PER_PAGE = 20

  # @filters and @pages may already be set by DashboardReflex; otherwise
  # fall back to the URL params for a normal page load.
  def index
    @filters ||= HuntStatsFilters.parse(params[:filters])
    @pages ||= 1

    response = HuntStatsService.new.draw_results_by_code(
      filters: @filters,
      page: 1,
      per_page: PER_PAGE * @pages
    )

    @draw_results = response[:results]
    @has_more = response[:has_more]
    @total_count = response[:total_count]
    @max_points = response[:global_max_points]
    @showing_count = [PER_PAGE * @pages, @total_count].min

    # A single weighted-draw species swaps the preference-point columns for weighted ones.
    @weighted_view = HuntStat::WEIGHTED_SPECIES.include?(@filters[:species])
    unless @weighted_view
      # Mixed view keeps the preference-point columns; just flag the weighted hunts.
      @weighted_codes = WeightedStat.where(hunt_code: @draw_results.keys).distinct.pluck(:hunt_code)
      return
    end

    service = HuntStatsService.new
    @weighted = service.weighted_results(@draw_results.keys)
    @max_weighted = service.max_weighted_points(@filters[:species])
  end
end
