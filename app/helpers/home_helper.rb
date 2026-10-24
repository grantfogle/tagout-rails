module HomeHelper
  # Link into the dashboard pre-filtered for this species, using the existing
  # HuntStatsFilters params. Points/residency are included only when known.
  def dashboard_path_for(profile, species)
    filters = { species: species }
    points = profile&.points_for(species)
    filters[:points] = points unless points.nil?
    filters[:resident] = profile.resident unless profile.nil? || profile.resident.nil?
    dashboard_path(filters: filters)
  end
end
