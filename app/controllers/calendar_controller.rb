class CalendarController < ApplicationController
  before_action :authenticate_user!

  def index
    @species = params[:species].presence_in(HuntStat::SPECIES_OPTIONS)
    @mine_only = params[:mine] == "1"
    @months = CalendarService.new(current_user).year(species: @species, mine_only: @mine_only)
  end
end
