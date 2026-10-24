# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Tagout is a Rails 6.1 app (Ruby 3.1.3, Node per `.node-version`, Yarn 1) that shows Colorado big-game draw statistics (Elk, Deer, Pronghorn) by hunt code: preference points, choice draws, applicants, success and odds. Uses Postgres, Devise auth, Webpacker 5 (webpack 4), Turbolinks, Stimulus and StimulusReflex/CableReady.

## Commands

```bash
bundle install && yarn install
bin/rails db:create db:migrate db:seed   # seeds load db/seeds/co_*_stats.json
bin/rails server                         # also run bin/webpack-dev-server for JS
bin/rails test                           # all tests (Minitest, test/)
bin/rails test test/models/user_test.rb  # single file
bin/rails test test/models/user_test.rb:12  # single test by line
```

- Redis is required for Action Cable (StimulusReflex) in development: `redis://localhost:6379/1` (`config/cable.yml`). Production uses `REDIS_URL`.
- Webpacker 5 / webpack 4 with Babel plugins pinned in `babel.config.js`; if Node is too new, the build may need `NODE_OPTIONS=--openssl-legacy-provider`.

## Architecture

- **Routes** (`config/routes.rb`): root is `dashboard#index` for signed-in users and `home#index` otherwise (Devise `authenticated`/`unauthenticated` roots). `hunt_stats` routes are declared but there is no `HuntStatsController` yet. `feedbacks#create` stores `Feedback` records.
- **Dashboard flow**: `DashboardController#index` (requires login) whitelists filter params, casts `resident`/`adult` to booleans, and calls `HuntStatsService#draw_results_by_code`. It responds to both `html` and `js` (`index.js.erb` + `_table_rows.html.erb`) for paginated "load more" appends.
- **`HuntStatsService`** (`app/services/`) holds all query/aggregation logic: filters, pagination by distinct `hunt_code`, and building per-code hashes split into `resident`/`nonresident` with `pref` (by points) and `choice` (2nd–4th choice; 1st choice is skipped) data. `grouped_draw_results` is legacy. `global_max_points` is computed across all filtered data so table columns stay consistent across pages.
- **`HuntStat` model**: one row per (hunt_code, draw_type, value, resident, adult). `draw_type` is `"pref"` or `"total_choice"`; `value` is points or choice number. Allowed species/sex/method/season values are constants on the model and also drive the filter dropdowns.
- **StimulusReflex**: reflexes live in `app/reflexes/` (only `ApplicationReflex` so far); client config is in `app/javascript/config/` and Stimulus controllers in `app/javascript/controllers/`. Entry pack is `app/javascript/packs/application.js`.
- Several `*.rb.bak` files in `app/` are leftovers from the StimulusReflex install; ignore them.

## Deployment

Fly.io (`fly.toml`, app `tagout-rails`, region `lax`); pushes to `main` trigger `.github/workflows/fly-deploy.yml`, and the release command runs `bin/rails db:prepare`. A `Dockerfile` is generated via `dockerfile-rails` (`config/dockerfile.yml`). `tagout.dump` in the repo root is a database dump.
