require "json"

def seed_hunt_stats(filename)
  path = Rails.root.join("db/seeds/#{filename}")
  rows = JSON.parse(File.read(path))

  now = Time.current
  batch_size = 5_000

  rows.each_slice(batch_size) do |slice|
    payload = slice.map do |r|
      {
        hunt_code:  r["hunt_code"],
        state:      r["state"],
        species:    r["species"],
        sex:        r["sex"],
        unit:       r["unit"],
        season:     r["season"],
        hunt_method:     r["method"],
        resident:   r["resident"],
        adult:      r["adult"],
        draw_type:  r["type"],          # map JSON "type" -> DB "draw_type"
        value:      r["value"].to_i,
        applicants: r["applicants"].to_i,
        success:    r["success"].to_i,
        created_at: now,
        updated_at: now
      }
    end

    # De-duplicate by unique key (same combo can appear twice in batch)
    payload.uniq! { |r| [r[:hunt_code], r[:resident], r[:adult], r[:draw_type], r[:value]] }

    HuntStat.upsert_all(payload, unique_by: "index_hunt_stats_unique_key")
  end

  puts "Seeded #{rows.size} records from #{filename}"
end

# Seed all hunt stats
seed_hunt_stats("co_elk_stats.json")
seed_hunt_stats("co_deer_stats.json")
seed_hunt_stats("co_pronghorn_stats.json")
seed_hunt_stats("co_bear_stats.json")
seed_hunt_stats("co_desert_bighorn_stats.json")
seed_hunt_stats("co_rocky_mountain_bighorn_stats.json")
seed_hunt_stats("co_mountain_goat_stats.json")
seed_hunt_stats("co_moose_stats.json")

def seed_weighted_stats(filename)
  rows = JSON.parse(File.read(Rails.root.join("db/seeds/#{filename}")))
  now = Time.current

  rows.each_slice(5_000) do |slice|
    payload = slice.map do |r|
      {
        hunt_code:         r["hunt_code"],
        resident:          r["resident"],
        adult:             r["adult"],
        preference_points: r["preference_points"].to_i,
        weighted_points:   r["weighted_points"].to_i,
        applicants:        r["applicants"].to_i,
        success:           r["success"].to_i,
        created_at:        now,
        updated_at:        now
      }
    end

    WeightedStat.upsert_all(payload, unique_by: "index_weighted_stats_unique_key")
  end

  puts "Seeded #{rows.size} weighted records from #{filename}"
end

seed_weighted_stats("co_rocky_mountain_bighorn_weighted.json")
seed_weighted_stats("co_mountain_goat_weighted.json")
seed_weighted_stats("co_moose_weighted.json")
