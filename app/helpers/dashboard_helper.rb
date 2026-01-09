module DashboardHelper
  def display_odds(cell)
    return "—" unless cell && cell[:applicants] && cell[:applicants] > 0
    
    if cell[:odds] == 100.0
      "100%"
    elsif cell[:odds] == 0.0
      "0%"
    elsif cell[:odds]
      "#{cell[:odds]}%"
    else
      "—"
    end
  end

  def cell_class(cell)
    return "draw-cell--empty" unless cell && cell[:applicants] && cell[:applicants] > 0
    
    odds = cell[:odds] || 0
    
    if odds >= 100
      "draw-cell--guaranteed"
    elsif odds >= 50
      "draw-cell--high"
    elsif odds > 0
      "draw-cell--low"
    else
      "draw-cell--none"
    end
  end
end
