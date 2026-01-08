class DashboardController < ApplicationController
  def index
    @filters = params.fetch(:filters, {})
                    .permit(:hunt_code, :state, :species, :sex, :hunt_method, :resident, :adult, :draw_type)
                    .to_h
                    .symbolize_keys

    @filters[:resident] = cast_bool(@filters[:resident])
    @filters[:adult]    = cast_bool(@filters[:adult])

    @draw_results = HuntStatsService.new.draw_results_by_code(filters: @filters)
    
    # Calculate the global max points across all hunt codes for consistent column headers
    @max_points = @draw_results.values.map { |v| v[:max_points] }.max || 0
  end

  private

  def cast_bool(val)
    return nil if val.nil?
    return true  if val.to_s.downcase == "true"
    return false if val.to_s.downcase == "false"
    nil
  end
end
