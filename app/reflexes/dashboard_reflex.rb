# frozen_string_literal: true

# State is carried by the page itself (the filter form and the load-more button's
# data attributes) rather than the session. Instance variables set here are copied
# onto DashboardController before #index renders the page.
class DashboardReflex < ApplicationReflex
  MAX_PAGES = 25

  def filter
    # `params` merges the page URL over the form, so stale ?filters[...] in the URL
    # would override what the user just picked. Read the submitted form directly.
    @filters = HuntStatsFilters.parse(data.form_params["filters"])
    @pages = 1
  end

  def load_more
    @filters = HuntStatsFilters.parse(parsed_filters)
    @pages = (element.dataset[:pages].to_i + 1).clamp(1, MAX_PAGES)
  end

  private

  def parsed_filters
    JSON.parse(element.dataset[:filters].presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
