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