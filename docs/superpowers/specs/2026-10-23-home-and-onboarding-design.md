# Home Screen, Features Page, and Skippable Onboarding

Date: 2026-10-23

## Goals

- Make the signed-in home screen about the user (greeting, profile, preference points, quick links into the dashboard).
- Add a `/features` page that splits the app into Current and Future features.
- Add a profile form for new users. It is skippable and never blocks access.

## Current State

- `users` has only Devise columns; there is no profile data.
- Signed-in root is `dashboard#index` (draw stats table). Signed-out root is `home#index` (marketing page).
- No features page exists.
- `HuntStat` already defines `SPECIES_OPTIONS` and `METHOD_OPTIONS`; `HuntStatsFilters` already parses dashboard filter params (`species`, `resident`, `points`, ...).

## Decisions

- Profile data lives in a separate `Profile` model (`User has_one :profile`), not on `users` and not in jsonb.
- Onboarding is skippable: no redirect gate. A banner on the home screen prompts users without a profile.
- `/features` is public.
- Notification emails are out of scope; only the opt-in flag is stored.
- Only Colorado has data. Other states are selectable in the form but shown as "coming soon".

## Routes

- Signed-in root becomes `home#index` (personal home). Signed-out root stays `home#index` (marketing view). `HomeController` renders the matching template.
- `/dashboard` unchanged (draw stats table).
- `get "/features", to: "features#index"`: public.
- `resource :profile, only: [:new, :create, :edit, :update]` (authenticated).
- Navbar (signed in): Home, Dashboard, Features, Logout. Also fix the stray `</ul>` in the signed-out branch.

## Data Model

`profiles`
- `user_id` (unique index, not null)
- `name` (string, required)
- `residency_state` (string, 2-letter code)
- `resident` (boolean; true when `residency_state == "CO"`)
- `favorite_species` (string array)
- `states_of_interest` (string array)
- `preferred_methods` (string array)
- `notifications_enabled` (boolean, default false)

`preference_points`
- `profile_id`, `species`, `points` (integer 0–99)
- unique index on `(profile_id, species)`

Associations: `User has_one :profile, dependent: :destroy`; `Profile has_many :preference_points, dependent: :destroy` with `accepts_nested_attributes_for`.

Validations: `name` presence; species and methods checked against `HuntStat::SPECIES_OPTIONS` / `METHOD_OPTIONS`; `residency_state` and `states_of_interest` checked against `Profile::STATES`; points between 0 and 99; one `PreferencePoint` per species per profile.

## Profile Form

Shared partial for `profiles#new` and `profiles#edit`. Plain Rails form (no StimulusReflex). Sections: Name, Residency (state select), Favorite species, States of interest, Preferred methods, Preference points (one number input per checked favorite species), Notifications toggle.

A small Stimulus controller shows/hides the points inputs as species checkboxes change. "Skip for now" links to the home screen. Create/update redirect to the home screen with a flash message.

## Home Screen

- With profile: greeting by name; cards for favorite species and points, each linking to `/dashboard?filters[species]=...&filters[points]=...&filters[resident]=...` using existing `HuntStatsFilters` params. No new query logic.
- Without profile: "Finish your profile" banner linking to `profiles#new`, plus generic quick links.

## Features Page

Two sections.
- Current: Colorado draw stats for Elk, Deer and Pronghorn; filters; feedback form.
- Future: other states, preference point tracker, deadline and draw-result notifications.

## Testing (Minitest)

- `Profile` model: validations, points uniqueness, species/method/state inclusion.
- `ProfilesController`: create/update happy path and invalid params; signed-out users redirected to sign in.
- `HomeController#index`: signed-in with profile; signed-in without profile (banner shown); signed-out marketing view.
- `FeaturesController#index`: renders for signed-out users.

## Out of Scope

- Sending notification emails.
- Draw data for states other than Colorado.
- Group/party applications and license numbers.
