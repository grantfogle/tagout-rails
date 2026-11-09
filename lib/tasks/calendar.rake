namespace :calendar do
  desc "Load public calendar events from db/calendar/*.yml"
  task load: :environment do
    puts "Loaded #{CalendarLoader.call} calendar events"
  end
end
