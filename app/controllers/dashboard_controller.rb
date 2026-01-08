class DashboardController < ApplicationController
  PER_PAGE = 20

  def index
    @filters = extract_filters
    @page = (params[:page] || 1).to_i
    
    response = HuntStatsService.new.draw_results_by_code(
      filters: @filters,
      page: @page,
      per_page: PER_PAGE
    )
    
    @draw_results = response[:results]
    @has_more = response[:has_more]
    @next_page = response[:next_page]
    @total_count = response[:total_count]
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  private

  def extract_filters
    filters = params.fetch(:filters, {})
                    .permit(:hunt_code, :state, :species, :sex, :hunt_method, :resident, :adult, :draw_type)
                    .to_h
                    .symbolize_keys

    filters[:resident] = cast_bool(filters[:resident])
    filters[:adult]    = cast_bool(filters[:adult])
    filters
  end

  def cast_bool(val)
    return nil if val.nil?
    return true  if val.to_s.downcase == "true"
    return false if val.to_s.downcase == "false"
    nil
  end
end
