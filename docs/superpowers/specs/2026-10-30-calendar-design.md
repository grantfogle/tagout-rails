# Calendar design

## Goal

Show signed-in users upcoming hunting dates. The home page lists the next 30 days. A dedicated page shows the next 12 months.

## Scope

In:
- CPW key dates (application deadline, draw results, leftover sales, point-purchase deadline).
- Season dates by species (archery, muzzleloader, rifle).
- Personal reminders created by the user.
- A `state` column on every event so other states can be added later as data. Only `CO` is loaded now.

Out (can be added later): recurring reminders, email or push notifications, iCal export, a day-grid view, an admin UI.

## Data model

`calendar_events`

| column | type | notes |
| --- | --- | --- |
| `title` | string, required | |
| `kind` | string, required | e.g. `deadline`, `draw_results`, `leftover`, `season`, `reminder` |
| `state` | string, required, default `CO` | |
| `species` | string, nullable | validated against `HuntStat` species constants; NULL means applies to all |
| `starts_on` | date, required | |
| `ends_on` | date, nullable | for seasons and other ranges |
| `user_id` | references, nullable | NULL = public event; set = personal reminder |
| `notes` | text, nullable | |

Indexes: `starts_on`; `user_id`. No unique index: Postgres treats NULL `species` values as distinct, so it wouldn't enforce uniqueness for all-species events. The loader enforces it instead (see below).

Scopes:
- `between(from, to)`: events overlapping the window (`starts_on <= to` and `COALESCE(ends_on, starts_on) >= from`).
- `visible_to(user)`: public events plus the user's own reminders.
- `for_species(list)`: events with NULL species, or species in the list.

## Loading public events

- Source files: `db/calendar/<year>.yml`, checked in. (`db/seeds/*` is gitignored, so it is not used.)
- `rake calendar:load` reads every file and upserts public events with `find_or_initialize_by(state:, kind:, species:, starts_on:, title:)` (`user_id` NULL). Safe to rerun; `find_or_initialize_by` matches NULL species correctly.
- The file is updated once a year when CPW publishes its dates.

## Service

`CalendarService` (`app/services/`), following the `HuntStatsService` pattern:
- `upcoming(user, days: 30)` returns events from today through today + `days`, sorted by `starts_on`.
- `year(user, species: nil, mine_only: false)` returns the next 12 months, as an ordered hash of month => events.
- Both apply `visible_to(user)`. Species filtering: an explicit `species:` argument wins; otherwise the profile's `favorite_species` is used if the profile has any; otherwise all species are shown.

## UI

- **Home** (`home/personal`): "Next 30 days" section. A date-sorted list with a date badge, title and kind, and a "View full year" link. Empty state: "Nothing in the next 30 days." Not shown to signed-out visitors.
- **Year view** (`GET /calendar`, login required): twelve month sections, each a list of events. Controls: species filter, "Mine only" toggle. List-style months rather than day grids, which read better on mobile.
- **Reminders**: `resources :calendar_events, only: [:new, :create, :edit, :update, :destroy]`. Scoped to `current_user`; a user cannot view or change another user's reminders or any public event.

## Testing (Minitest)

- Model: validations, `between` (including ranges that straddle the window edges), `visible_to`, `for_species`.
- Service: 30-day window, month grouping, species filtering, mine-only.
- Loader: idempotent on rerun; updates a changed row rather than duplicating.
- Controllers: login required; one user never sees or edits another user's reminders; public events cannot be edited through `calendar_events`.
