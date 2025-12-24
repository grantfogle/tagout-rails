class DashboardController < ApplicationController
  def index
    @filters = params.fetch(:filters, {})
                    .permit(:hunt_code, :state, :species, :sex, :hunt_method, :resident, :adult, :draw_type)
                    .to_h
                    .symbolize_keys

    @filters[:resident] = cast_bool(@filters[:resident])
    @filters[:adult]    = cast_bool(@filters[:adult])

    @hunt_results_by_code = HuntStatsService.new.grouped_draw_results(
      limit_per_code: (params[:limit_per_code].presence || 50).to_i,
      filters: @filters
    )
  end

  private

  def cast_bool(val)
    return nil if val.nil?
    return true  if val.to_s.downcase == "true"
    return false if val.to_s.downcase == "false"
    nil
  end
end
