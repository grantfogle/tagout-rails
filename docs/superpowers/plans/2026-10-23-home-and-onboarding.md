# Home Screen, Features Page, and Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give signed-in users a personal home screen, add a public Current/Future features page, and add a skippable profile form for new users.

**Architecture:** A new `Profile` model (`User has_one :profile`) plus a `PreferencePoint` table hold onboarding data. `HomeController#index` renders a marketing view for signed-out users and a personal view for signed-in users. `ProfilesController` (singular resource) serves the shared new/edit form. `FeaturesController` renders a static public page. No redirect gate: users without a profile see a banner.

**Tech Stack:** Rails 6.1, Ruby 3.1.3, Postgres (array columns), Devise, Webpacker 5 + Stimulus, SCSS, Minitest.

**Spec:** `docs/superpowers/specs/2026-10-23-home-and-onboarding-design.md`

## Global Constraints

- Run tests with `bin/rails test`. If the Webpacker compile fails on a new Node, prefix with `NODE_OPTIONS=--openssl-legacy-provider`.
- Species and methods validate against `HuntStat::SPECIES_OPTIONS` and `HuntStat::METHOD_OPTIONS` (single source of truth).
- Preference points are integers 0–99 (matches the cap in `HuntStatsFilters`).
- Onboarding is skippable: never redirect a signed-in user to the profile form.
- `/features` is public (no authentication).
- Profile form is a plain Rails form (`local: true`); no StimulusReflex.
- Dashboard links from the home screen reuse existing `HuntStatsFilters` params (`filters[species]`, `filters[points]`, `filters[resident]`); no new query logic.
- Only Colorado has data. Other states are selectable but labeled "coming soon".
- Out of scope: sending notification emails, data for non-Colorado states, party applications, license numbers.
- Ignore the `*.rb.bak` files in `app/`.
- Every commit message ends with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (pass it as a second `-m`).

## File Structure

| File | Responsibility |
|---|---|
| `test/test_helper.rb` (modify) | Add Devise integration helpers |
| `test/fixtures/users.yml`, `test/fixtures/hunt_stats.yml` (modify) | Valid fixtures (current ones break the suite) |
| `db/migrate/20261023000000_create_profiles_and_preference_points.rb` (create) | Schema |
| `app/models/profile.rb`, `app/models/preference_point.rb` (create) | Domain models + validations |
| `app/models/user.rb` (modify) | `has_one :profile` |
| `config/routes.rb` (modify) | Roots, `/features`, `resource :profile` |
| `app/controllers/home_controller.rb` (modify) | Marketing vs personal view |
| `app/helpers/home_helper.rb` (create) | `dashboard_path_for(profile, species)` |
| `app/views/home/index.html.erb` (modify), `app/views/home/personal.html.erb` (create) | Marketing + personal home |
| `app/views/shared/_navbar.html.erb` (modify) | Nav links, markup fix |
| `app/controllers/features_controller.rb`, `app/views/features/index.html.erb` (create) | Features page |
| `app/controllers/profiles_controller.rb` (create) | new/create/edit/update |
| `app/views/profiles/{_form,new,edit}.html.erb` (create) | Profile form |
| `app/javascript/controllers/profile_form_controller.js` (create) | Show/hide points inputs |
| `app/assets/stylesheets/components/_home.scss`, `_profile.scss` (create); `application.scss` (modify) | Styling |
| `CLAUDE.md` (modify) | Document new routes/models |

---

### Task 1: Repair the test baseline

The suite is red before any change: `users.yml` has blank-email rows that collide on the unique email index, `hunt_stats.yml` uses a column (`method`) that was renamed to `hunt_method`, and the controller tests reference routes that don't exist.

**Files:**
- Modify: `test/test_helper.rb`, `test/fixtures/users.yml`, `test/fixtures/hunt_stats.yml`, `test/controllers/home_controller_test.rb`, `test/controllers/dashboard_controller_test.rb`

**Interfaces:**
- Produces: fixtures `users(:alice)` (no profile) and `users(:bob)`; `sign_in` helper in integration tests.

- [ ] **Step 1: Confirm the suite is red**

Run: `bin/rails test`
Expected: errors in fixture loading (`2 runs, 0 assertions, 0 failures, 2 errors`).

- [ ] **Step 2: Replace `test/fixtures/users.yml`**

```yaml
alice:
  email: alice@example.com
  encrypted_password: <%= Devise::Encryptor.digest(User, "password123") %>

bob:
  email: bob@example.com
  encrypted_password: <%= Devise::Encryptor.digest(User, "password123") %>
```

- [ ] **Step 3: Replace `test/fixtures/hunt_stats.yml`**

```yaml
elk_pref:
  hunt_code: EE001O1R
  state: CO
  species: Elk
  sex: E
  unit: "001"
  season: O1
  hunt_method: Rifle
  resident: true
  adult: true
  draw_type: pref
  value: 1
  applicants: 10
  success: 5

elk_choice:
  hunt_code: EE001O1R
  state: CO
  species: Elk
  sex: E
  unit: "001"
  season: O1
  hunt_method: Rifle
  resident: true
  adult: true
  draw_type: total_choice
  value: 2
  applicants: 8
  success: 2
```

- [ ] **Step 4: Add Devise helpers to `test/test_helper.rb`** (append after the `ActiveSupport::TestCase` class)

```ruby
class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```

- [ ] **Step 5: Replace `test/controllers/home_controller_test.rb`**

```ruby
require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors get the marketing page" do
    get root_url
    assert_response :success
  end
end
```

- [ ] **Step 6: Replace `test/controllers/dashboard_controller_test.rb`**

```ruby
require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects signed-out users to sign in" do
    get dashboard_url
    assert_redirected_to new_user_session_url
  end

  test "renders for signed-in users" do
    sign_in users(:alice)
    get dashboard_url
    assert_response :success
  end
end
```

- [ ] **Step 7: Run the suite**

Run: `bin/rails test`
Expected: PASS (3 runs, 0 failures). If the dashboard test fails inside `HuntStatsService`, read the error and fix the fixture data (not the service); if it fails compiling Webpacker, use the `NODE_OPTIONS` prefix from Global Constraints.

- [ ] **Step 8: Commit**

```bash
git add test/
git commit -m "test: repair fixtures and stale controller tests" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Profile and PreferencePoint models

**Files:**
- Create: `db/migrate/20261023000000_create_profiles_and_preference_points.rb`, `app/models/profile.rb`, `app/models/preference_point.rb`, `test/models/profile_test.rb`, `test/models/preference_point_test.rb`
- Modify: `app/models/user.rb`, `test/models/user_test.rb`, `db/schema.rb` (generated)

**Interfaces:**
- Produces:
  - `Profile::STATES` (Hash code→name, all 50 states), `Profile::TRACKABLE_STATES` (Array of codes), `Profile::AVAILABLE_STATES` (`%w[CO]`)
  - `Profile#points_for(species) -> Integer | nil`
  - `Profile#residency_label -> String | nil` (e.g. `"Colorado resident"`)
  - `Profile#resident -> true | false | nil` (derived from `residency_state`)
  - Nested attributes `preference_points_attributes` (blank `points` are rejected)
  - `User#profile`

- [ ] **Step 1: Write `test/models/profile_test.rb`**

```ruby
require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  def build_profile(**attrs)
    Profile.new({ user: users(:alice), name: "Alice" }.merge(attrs))
  end

  test "valid with just a name" do
    assert build_profile.valid?
  end

  test "requires a name" do
    profile = build_profile(name: "")
    assert_not profile.valid?
    assert_includes profile.errors[:name], "can't be blank"
  end

  test "one profile per user" do
    build_profile.save!
    assert_not build_profile.valid?
  end

  test "resident is derived from residency state" do
    assert_equal true, build_profile(residency_state: "CO").tap(&:valid?).resident
    assert_equal false, build_profile(residency_state: "WY").tap(&:valid?).resident
    assert_nil build_profile(residency_state: "").tap(&:valid?).resident
  end

  test "rejects unknown residency state" do
    assert_not build_profile(residency_state: "ZZ").valid?
  end

  test "rejects unknown species, methods and states of interest" do
    assert_not build_profile(favorite_species: ["Moose"]).valid?
    assert_not build_profile(preferred_methods: ["Crossbow"]).valid?
    assert_not build_profile(states_of_interest: ["ZZ"]).valid?
  end

  test "accepts known species, methods and states of interest" do
    profile = build_profile(favorite_species: %w[Elk Deer], preferred_methods: ["Rifle"], states_of_interest: %w[CO WY])
    assert profile.valid?
  end

  test "strips blank and duplicate array entries" do
    profile = build_profile(favorite_species: ["", "Elk", "Elk"])
    profile.valid?
    assert_equal ["Elk"], profile.favorite_species
  end

  test "nested points: blank points are rejected, filled ones saved" do
    profile = build_profile(
      favorite_species: %w[Elk Deer],
      preference_points_attributes: [
        { species: "Elk", points: "6" },
        { species: "Deer", points: "" }
      ]
    )
    profile.save!
    assert_equal [["Elk", 6]], profile.preference_points.map { |p| [p.species, p.points] }
  end

  test "points_for returns points for a species or nil" do
    profile = build_profile(preference_points_attributes: [{ species: "Elk", points: "4" }])
    assert_equal 4, profile.points_for("Elk")
    assert_nil profile.points_for("Deer")
  end

  test "residency_label" do
    assert_equal "Colorado resident", build_profile(residency_state: "CO").residency_label
    assert_equal "Wyoming resident", build_profile(residency_state: "WY").residency_label
    assert_nil build_profile.residency_label
  end
end
```

- [ ] **Step 2: Write `test/models/preference_point_test.rb`**

```ruby
require "test_helper"

class PreferencePointTest < ActiveSupport::TestCase
  setup do
    @profile = Profile.create!(user: users(:alice), name: "Alice")
  end

  test "valid point" do
    assert @profile.preference_points.build(species: "Elk", points: 0).valid?
    assert @profile.preference_points.build(species: "Deer", points: 99).valid?
  end

  test "points must be an integer between 0 and 99" do
    assert_not @profile.preference_points.build(species: "Elk", points: -1).valid?
    assert_not @profile.preference_points.build(species: "Elk", points: 100).valid?
    assert_not @profile.preference_points.build(species: "Elk", points: 1.5).valid?
    assert_not @profile.preference_points.build(species: "Elk", points: nil).valid?
  end

  test "species must be a known species" do
    assert_not @profile.preference_points.build(species: "Moose", points: 1).valid?
  end

  test "one row per species per profile" do
    @profile.preference_points.create!(species: "Elk", points: 1)
    assert_not @profile.preference_points.build(species: "Elk", points: 2).valid?
  end
end
```

- [ ] **Step 3: Add to `test/models/user_test.rb`** (inside the class, replacing the commented example)

```ruby
  test "has one profile, destroyed with the user" do
    user = users(:alice)
    Profile.create!(user: user, name: "Alice")
    assert_difference("Profile.count", -1) { user.destroy }
  end
```

- [ ] **Step 4: Run to verify failure**

Run: `bin/rails test test/models`
Expected: FAIL / ERROR with `uninitialized constant Profile`.

- [ ] **Step 5: Create the migration `db/migrate/20261023000000_create_profiles_and_preference_points.rb`**

```ruby
class CreateProfilesAndPreferencePoints < ActiveRecord::Migration[6.1]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :residency_state
      t.boolean :resident
      t.string :favorite_species, array: true, default: [], null: false
      t.string :states_of_interest, array: true, default: [], null: false
      t.string :preferred_methods, array: true, default: [], null: false
      t.boolean :notifications_enabled, default: false, null: false
      t.timestamps
    end

    create_table :preference_points do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :species, null: false
      t.integer :points, null: false
      t.timestamps
    end
    add_index :preference_points, [:profile_id, :species], unique: true
  end
end
```

- [ ] **Step 6: Create `app/models/preference_point.rb`**

```ruby
class PreferencePoint < ApplicationRecord
  belongs_to :profile

  validates :species, inclusion: { in: HuntStat::SPECIES_OPTIONS }
  validates :species, uniqueness: { scope: :profile_id }
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 99 }
end
```

- [ ] **Step 7: Create `app/models/profile.rb`**

```ruby
class Profile < ApplicationRecord
  STATES = {
    "AL" => "Alabama", "AK" => "Alaska", "AZ" => "Arizona", "AR" => "Arkansas", "CA" => "California",
    "CO" => "Colorado", "CT" => "Connecticut", "DE" => "Delaware", "FL" => "Florida", "GA" => "Georgia",
    "HI" => "Hawaii", "ID" => "Idaho", "IL" => "Illinois", "IN" => "Indiana", "IA" => "Iowa",
    "KS" => "Kansas", "KY" => "Kentucky", "LA" => "Louisiana", "ME" => "Maine", "MD" => "Maryland",
    "MA" => "Massachusetts", "MI" => "Michigan", "MN" => "Minnesota", "MS" => "Mississippi", "MO" => "Missouri",
    "MT" => "Montana", "NE" => "Nebraska", "NV" => "Nevada", "NH" => "New Hampshire", "NJ" => "New Jersey",
    "NM" => "New Mexico", "NY" => "New York", "NC" => "North Carolina", "ND" => "North Dakota", "OH" => "Ohio",
    "OK" => "Oklahoma", "OR" => "Oregon", "PA" => "Pennsylvania", "RI" => "Rhode Island", "SC" => "South Carolina",
    "SD" => "South Dakota", "TN" => "Tennessee", "TX" => "Texas", "UT" => "Utah", "VT" => "Vermont",
    "VA" => "Virginia", "WA" => "Washington", "WV" => "West Virginia", "WI" => "Wisconsin", "WY" => "Wyoming"
  }.freeze
  # States offered as "interested in" checkboxes in the form.
  TRACKABLE_STATES = %w[CO WY MT ID UT NM AZ NV OR WA].freeze
  # States that actually have draw data today.
  AVAILABLE_STATES = %w[CO].freeze

  ARRAY_ATTRIBUTES = %i[favorite_species states_of_interest preferred_methods].freeze

  belongs_to :user
  has_many :preference_points, dependent: :destroy
  accepts_nested_attributes_for :preference_points, reject_if: ->(attrs) { attrs["points"].blank? }

  before_validation :normalize

  validates :name, presence: true
  validates :user_id, uniqueness: true
  validates :residency_state, inclusion: { in: STATES.keys }, allow_blank: true
  validate :array_values_allowed

  def points_for(species)
    preference_points.find { |point| point.species == species }&.points
  end

  def residency_label
    "#{STATES[residency_state]} resident" if residency_state.present?
  end

  private

  def normalize
    ARRAY_ATTRIBUTES.each { |attr| self[attr] = Array(self[attr]).compact_blank.uniq }
    self.resident = residency_state.present? ? residency_state == "CO" : nil
  end

  def array_values_allowed
    check_subset(:favorite_species, HuntStat::SPECIES_OPTIONS)
    check_subset(:preferred_methods, HuntStat::METHOD_OPTIONS)
    check_subset(:states_of_interest, STATES.keys)
  end

  def check_subset(attr, allowed)
    invalid = self[attr] - allowed
    errors.add(attr, "includes invalid values: #{invalid.join(', ')}") if invalid.any?
  end
end
```

- [ ] **Step 8: Add the association in `app/models/user.rb`** (after the `devise` call)

```ruby
  has_one :profile, dependent: :destroy
```

- [ ] **Step 9: Migrate and run tests**

Run: `bin/rails db:migrate && bin/rails test test/models`
Expected: PASS. `db/schema.rb` now contains `profiles` and `preference_points`.

- [ ] **Step 10: Commit**

```bash
git add db/ app/models test/models
git commit -m "feat: add Profile and PreferencePoint models" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Routes, home screen, and navbar

**Files:**
- Modify: `config/routes.rb`, `app/controllers/home_controller.rb`, `app/views/home/index.html.erb`, `app/views/shared/_navbar.html.erb`, `test/controllers/home_controller_test.rb`
- Create: `app/helpers/home_helper.rb`, `app/views/home/personal.html.erb`, `test/helpers/home_helper_test.rb`

**Interfaces:**
- Consumes: `Profile#points_for`, `Profile#residency_label`, `Profile#resident`, `User#profile` (Task 2).
- Produces: route helpers `features_path`, `new_profile_path`, `edit_profile_path`, `profile_path`, `dashboard_path`; `HomeHelper#dashboard_path_for(profile_or_nil, species) -> String`.

> `features_path` and `profile` routes point at controllers built in Tasks 4–5. Route helpers resolve without the controllers existing, so Task 3's tests pass; the links 404 until those tasks land.

- [ ] **Step 1: Write `test/helpers/home_helper_test.rb`**

```ruby
require "test_helper"

class HomeHelperTest < ActionView::TestCase
  def filters_for(path)
    Rack::Utils.parse_nested_query(URI(path).query)["filters"]
  end

  test "builds a dashboard link from species, points and residency" do
    profile = Profile.new(
      user: users(:alice), name: "Alice", residency_state: "CO",
      preference_points_attributes: [{ species: "Elk", points: "6" }]
    )
    profile.valid?
    assert_equal({ "species" => "Elk", "points" => "6", "resident" => "true" }, filters_for(dashboard_path_for(profile, "Elk")))
  end

  test "omits points when none are recorded for the species" do
    profile = Profile.new(user: users(:alice), name: "Alice", residency_state: "WY")
    profile.valid?
    assert_equal({ "species" => "Deer", "resident" => "false" }, filters_for(dashboard_path_for(profile, "Deer")))
  end

  test "works without a profile" do
    assert_equal({ "species" => "Elk" }, filters_for(dashboard_path_for(nil, "Elk")))
  end
end
```

- [ ] **Step 2: Replace `test/controllers/home_controller_test.rb`**

```ruby
require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors get the marketing page and public nav" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", new_user_registration_path
    assert_select "a[href=?]", features_path
    assert_select "a[href=?]", dashboard_path, count: 0
  end

  test "signed-in user without a profile sees the finish-profile banner" do
    sign_in users(:alice)
    get root_url
    assert_response :success
    assert_select ".banner", text: /Finish your profile/
    assert_select "a[href=?]", new_profile_path
  end

  test "signed-in user with a profile sees a personal home screen" do
    user = users(:bob)
    Profile.create!(
      user: user, name: "Bob Hunter", residency_state: "CO", favorite_species: %w[Elk],
      preference_points_attributes: [{ species: "Elk", points: "6" }]
    )
    sign_in user
    get root_url
    assert_response :success
    assert_select "h1", text: /Welcome back, Bob Hunter/
    assert_select ".banner", count: 0
    assert_select "a[href=?]", dashboard_path(filters: { species: "Elk", points: 6, resident: true })
    assert_select "a[href=?]", edit_profile_path
  end

  test "signed-in nav links to home, dashboard and features" do
    sign_in users(:alice)
    get root_url
    assert_select "a[href=?]", dashboard_path
    assert_select "a[href=?]", features_path
  end
end
```

- [ ] **Step 3: Run to verify failure**

Run: `bin/rails test test/controllers/home_controller_test.rb test/helpers`
Expected: FAIL (`undefined method features_path` / `dashboard_path_for`).

- [ ] **Step 4: Update `config/routes.rb`**

```ruby
Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "home#index", as: :authenticated_root
  end

  unauthenticated do
    root "home#index"
  end

  get "/dashboard", to: "dashboard#index"
  get "/features", to: "features#index"

  resource :profile, only: [:new, :create, :edit, :update]
  resources :hunt_stats, only: [:new, :create, :show]
  resources :feedbacks, only: [:create]
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
```

- [ ] **Step 5: Replace `app/controllers/home_controller.rb`**

```ruby
class HomeController < ApplicationController
  # Signed-out visitors get the marketing page; signed-in users get their personal home.
  def index
    return unless user_signed_in?

    @profile = current_user.profile
    render :personal
  end
end
```

- [ ] **Step 6: Create `app/helpers/home_helper.rb`**

```ruby
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
```

- [ ] **Step 7: Replace `app/views/home/index.html.erb`** (signed-out only now)

```erb
<div class="page">
  <header class="page__header">
    <h1 class="page__title">Get up to date draw odds for Big Game.</h1>
    <p class="page__subtitle">
      Sign up today.
    </p>
  </header>

  <section class="page__actions">
    <%= link_to "Sign up", new_user_registration_path, class: "button button--primary button--contained" %>
    <%= link_to "Sign in", new_user_session_path, class: "button button--secondary" %>
    <%= link_to "See what's coming", features_path, class: "button button--secondary" %>
  </section>
</div>
```

- [ ] **Step 8: Create `app/views/home/personal.html.erb`**

```erb
<div class="home">
  <header class="home__header">
    <% if @profile %>
      <h1 class="home__title">Welcome back, <%= @profile.name %>.</h1>
      <% if @profile.residency_label %>
        <p class="home__subtitle"><%= @profile.residency_label %></p>
      <% end %>
    <% else %>
      <h1 class="home__title">Welcome to Tagout.</h1>
      <p class="home__subtitle">Colorado big game draw odds, by hunt code.</p>
    <% end %>
  </header>

  <% unless @profile %>
    <aside class="banner">
      <div>
        <strong>Finish your profile</strong>
        <p>Tell us your species, points and states so we can tailor your odds.</p>
      </div>
      <%= link_to "Set up profile", new_profile_path, class: "button button--primary" %>
    </aside>
  <% end %>

  <section class="home__section">
    <h2 class="home__heading">Your species</h2>
    <% species_list = @profile&.favorite_species.presence || HuntStat::SPECIES_OPTIONS %>
    <div class="home__cards">
      <% species_list.each do |species| %>
        <%= link_to dashboard_path_for(@profile, species), class: "card home__card" do %>
          <span class="home__card-title"><%= species %></span>
          <% points = @profile&.points_for(species) %>
          <span class="home__card-meta">
            <%= points.nil? ? "No points recorded" : pluralize(points, "preference point") %>
          </span>
          <span class="home__card-cta">View draw odds &rarr;</span>
        <% end %>
      <% end %>
    </div>
  </section>

  <section class="home__section">
    <h2 class="home__heading">Quick links</h2>
    <div class="home__links">
      <%= link_to "Open dashboard", dashboard_path, class: "button button--primary" %>
      <%= link_to "Features", features_path, class: "button button--secondary" %>
      <% if @profile %>
        <%= link_to "Edit profile", edit_profile_path, class: "button button--secondary" %>
      <% end %>
    </div>
  </section>
</div>
```

- [ ] **Step 9: Replace `app/views/shared/_navbar.html.erb`** (also fixes the stray `</ul>`)

```erb
<nav class="navbar">
  <div class="navbar__container">
    <!-- Brand / Logo -->
    <div class="navbar__brand">
      <%= link_to "Tagout", root_path, class: "navbar__logo" %>
    </div>

    <ul class="navbar__links">
      <% if user_signed_in? %>
        <li><%= link_to "Home", root_path, class: "navbar__link" %></li>
        <li><%= link_to "Dashboard", dashboard_path, class: "navbar__link" %></li>
        <li><%= link_to "Features", features_path, class: "navbar__link" %></li>
        <li>
          <%= link_to "Logout", destroy_user_session_path,
              method: :delete,
              class: "navbar__link navbar__link--button" %>
        </li>
      <% else %>
        <li><%= link_to "Features", features_path, class: "navbar__link" %></li>
        <li><%= link_to "Login", new_user_session_path, class: "navbar__link" %></li>
        <li>
          <%= link_to "Sign up", new_user_registration_path,
              class: "navbar__link navbar__link--button" %>
        </li>
      <% end %>
    </ul>
  </div>
</nav>
```

- [ ] **Step 10: Run tests**

Run: `bin/rails test test/controllers/home_controller_test.rb test/helpers`
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add config/routes.rb app/controllers/home_controller.rb app/helpers app/views/home app/views/shared/_navbar.html.erb test/
git commit -m "feat: personal home screen, new routes, and navbar" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Features page

**Files:**
- Create: `app/controllers/features_controller.rb`, `app/views/features/index.html.erb`, `test/controllers/features_controller_test.rb`

**Interfaces:**
- Consumes: `features_path` route (Task 3).

- [ ] **Step 1: Write `test/controllers/features_controller_test.rb`**

```ruby
require "test_helper"

class FeaturesControllerTest < ActionDispatch::IntegrationTest
  test "renders for signed-out visitors with current and future sections" do
    get features_url
    assert_response :success
    assert_select "h2", text: "Current features"
    assert_select "h2", text: "Coming soon"
  end

  test "renders for signed-in users" do
    sign_in users(:alice)
    get features_url
    assert_response :success
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/controllers/features_controller_test.rb`
Expected: FAIL (`uninitialized constant FeaturesController` / routing error).

- [ ] **Step 3: Create `app/controllers/features_controller.rb`**

```ruby
class FeaturesController < ApplicationController
  def index
  end
end
```

- [ ] **Step 4: Create `app/views/features/index.html.erb`**

```erb
<div class="features">
  <header class="features__header">
    <h1 class="features__title">What Tagout does</h1>
    <p class="features__subtitle">What you can use today, and what we're building next.</p>
  </header>

  <section class="features__section">
    <h2 class="features__heading">Current features</h2>
    <div class="features__grid">
      <div class="card">
        <h3>Colorado draw stats</h3>
        <p>Preference points, choice draws, applicants, success and odds for Elk, Deer and Pronghorn, by hunt code.</p>
      </div>
      <div class="card">
        <h3>Filters</h3>
        <p>Narrow by species, sex, method, season, unit, residency and minimum odds, and highlight your own point level.</p>
      </div>
      <div class="card">
        <h3>Your profile</h3>
        <p>Save your species, points and methods so your home screen links straight to the odds that matter to you.</p>
      </div>
      <div class="card">
        <h3>Feedback</h3>
        <p>Tell us what's missing from the feedback button in the corner of the dashboard.</p>
      </div>
    </div>
  </section>

  <section class="features__section">
    <h2 class="features__heading">Coming soon</h2>
    <div class="features__grid">
      <div class="card">
        <h3>More states</h3>
        <p>Draw data beyond Colorado, starting with the Western states you can already mark as interesting in your profile.</p>
      </div>
      <div class="card">
        <h3>Preference point tracker</h3>
        <p>Track your points over time and see which hunts you're closing in on.</p>
      </div>
      <div class="card">
        <h3>Deadline &amp; results notifications</h3>
        <p>Reminders for application deadlines and draw result dates. You can opt in from your profile today.</p>
      </div>
    </div>
  </section>
</div>
```

- [ ] **Step 5: Run tests**

Run: `bin/rails test test/controllers/features_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/features_controller.rb app/views/features test/controllers/features_controller_test.rb
git commit -m "feat: add public features page" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Profile form and controller

**Files:**
- Create: `app/controllers/profiles_controller.rb`, `app/views/profiles/_form.html.erb`, `app/views/profiles/new.html.erb`, `app/views/profiles/edit.html.erb`, `app/javascript/controllers/profile_form_controller.js`, `test/controllers/profiles_controller_test.rb`

**Interfaces:**
- Consumes: `Profile` and nested `preference_points_attributes` (Task 2); `profile_path`, `new_profile_path`, `edit_profile_path`, `root_path` (Task 3).
- Produces: `/profile/new`, `POST /profile`, `/profile/edit`, `PATCH /profile`.

- [ ] **Step 1: Write `test/controllers/profiles_controller_test.rb`**

```ruby
require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  def valid_params
    {
      profile: {
        name: "Alice",
        residency_state: "CO",
        favorite_species: ["", "Elk"],
        states_of_interest: ["", "CO", "WY"],
        preferred_methods: ["", "Rifle"],
        notifications_enabled: "1",
        preference_points_attributes: {
          "0" => { species: "Elk", points: "6" },
          "1" => { species: "Deer", points: "" }
        }
      }
    }
  end

  test "signed-out users are sent to sign in" do
    get new_profile_url
    assert_redirected_to new_user_session_url
    post profile_url, params: valid_params
    assert_redirected_to new_user_session_url
  end

  test "new renders the form with a skip link" do
    sign_in users(:alice)
    get new_profile_url
    assert_response :success
    assert_select "form[action=?]", profile_path
    assert_select "a[href=?]", root_path, text: "Skip for now"
    assert_select "input[type=number][name*=points]", count: HuntStat::SPECIES_OPTIONS.size
  end

  test "new redirects to edit when a profile already exists" do
    Profile.create!(user: users(:alice), name: "Alice")
    sign_in users(:alice)
    get new_profile_url
    assert_redirected_to edit_profile_url
  end

  test "create saves the profile, derived residency and points" do
    sign_in users(:alice)
    assert_difference("Profile.count", 1) { post profile_url, params: valid_params }
    assert_redirected_to root_url

    profile = users(:alice).reload.profile
    assert_equal "Alice", profile.name
    assert_equal true, profile.resident
    assert_equal ["Elk"], profile.favorite_species
    assert_equal %w[CO WY], profile.states_of_interest
    assert_equal ["Rifle"], profile.preferred_methods
    assert profile.notifications_enabled
    assert_equal [["Elk", 6]], profile.preference_points.map { |p| [p.species, p.points] }
  end

  test "create with a blank name re-renders with 422" do
    sign_in users(:alice)
    assert_no_difference("Profile.count") do
      post profile_url, params: { profile: valid_params[:profile].merge(name: "") }
    end
    assert_response :unprocessable_entity
  end

  test "edit redirects to new when no profile exists" do
    sign_in users(:alice)
    get edit_profile_url
    assert_redirected_to new_profile_url
  end

  test "edit renders without a skip link" do
    Profile.create!(user: users(:alice), name: "Alice")
    sign_in users(:alice)
    get edit_profile_url
    assert_response :success
    assert_select "a", text: "Skip for now", count: 0
  end

  test "update changes attributes and existing points" do
    profile = Profile.create!(user: users(:alice), name: "Alice", preference_points_attributes: [{ species: "Elk", points: "3" }])
    point = profile.preference_points.first
    sign_in users(:alice)

    patch profile_url, params: { profile: {
      name: "Alice H.",
      preference_points_attributes: { "0" => { id: point.id, species: "Elk", points: "5" } }
    } }

    assert_redirected_to root_url
    assert_equal "Alice H.", profile.reload.name
    assert_equal 5, point.reload.points
  end

  test "update with invalid data re-renders with 422" do
    Profile.create!(user: users(:alice), name: "Alice")
    sign_in users(:alice)
    patch profile_url, params: { profile: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "users cannot edit another user's points" do
    other = Profile.create!(user: users(:bob), name: "Bob", preference_points_attributes: [{ species: "Elk", points: "9" }])
    Profile.create!(user: users(:alice), name: "Alice")
    sign_in users(:alice)

    patch profile_url, params: { profile: {
      preference_points_attributes: { "0" => { id: other.preference_points.first.id, points: "0" } }
    } }

    assert_equal 9, other.preference_points.first.reload.points
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/controllers/profiles_controller_test.rb`
Expected: FAIL (`uninitialized constant ProfilesController`).

- [ ] **Step 3: Create `app/controllers/profiles_controller.rb`**

```ruby
class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_edit_if_profile_exists, only: [:new, :create]
  before_action :set_profile, only: [:edit, :update]

  def new
    @profile = Profile.new(user: current_user)
    build_missing_points
  end

  def create
    @profile = Profile.new(profile_params)
    @profile.user = current_user

    if @profile.save
      redirect_to root_path, notice: "Profile saved."
    else
      build_missing_points
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_missing_points
  end

  def update
    if @profile.update(profile_params)
      redirect_to root_path, notice: "Profile updated."
    else
      build_missing_points
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_profile
    @profile = current_user.profile
    redirect_to new_profile_path unless @profile
  end

  def redirect_to_edit_if_profile_exists
    redirect_to edit_profile_path if current_user.profile
  end

  # One points input per species, so the form can show/hide them as favorites change.
  def build_missing_points
    existing = @profile.preference_points.map(&:species)
    (HuntStat::SPECIES_OPTIONS - existing).each do |species|
      @profile.preference_points.build(species: species)
    end
  end

  def profile_params
    params.require(:profile).permit(
      :name, :residency_state, :notifications_enabled,
      favorite_species: [], states_of_interest: [], preferred_methods: [],
      preference_points_attributes: [:id, :species, :points]
    )
  end
end
```

- [ ] **Step 4: Create `app/views/profiles/_form.html.erb`**

```erb
<%= form_with model: profile, url: profile_path, local: true,
      class: "form profile-form", data: { controller: "profile-form" } do |f| %>
  <% if profile.errors.any? %>
    <div class="alert alert--error">
      <ul>
        <% profile.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="form__field">
    <%= f.label :name, "Name" %>
    <%= f.text_field :name, required: true, autocomplete: "name" %>
  </div>

  <div class="form__field">
    <%= f.label :residency_state, "State of residency" %>
    <%= f.select :residency_state,
          Profile::STATES.map { |code, name| [name, code] },
          include_blank: "Select a state" %>
  </div>

  <fieldset class="form__field profile-form__group">
    <legend>Favorite species</legend>
    <%= f.collection_check_boxes :favorite_species, HuntStat::SPECIES_OPTIONS, :itself, :itself do |b| %>
      <label class="form__check">
        <%= b.check_box(data: { profile_form_target: "species", action: "change->profile-form#sync" }) %>
        <%= b.text %>
      </label>
    <% end %>
  </fieldset>

  <fieldset class="form__field profile-form__group">
    <legend>Preference points</legend>
    <p class="profile-form__hint">Pick favorite species above to enter your points.</p>
    <%= f.fields_for :preference_points do |pf| %>
      <div class="form__field" data-profile-form-target="points" data-species="<%= pf.object.species %>">
        <%= pf.hidden_field :species %>
        <%= pf.label :points, "#{pf.object.species} preference points" %>
        <%= pf.number_field :points, min: 0, max: 99 %>
      </div>
    <% end %>
  </fieldset>

  <fieldset class="form__field profile-form__group">
    <legend>States you're interested in</legend>
    <% state_options = Profile::TRACKABLE_STATES.map do |code|
         label = Profile::STATES[code]
         label += " (coming soon)" unless Profile::AVAILABLE_STATES.include?(code)
         [label, code]
       end %>
    <%= f.collection_check_boxes :states_of_interest, state_options, :last, :first do |b| %>
      <label class="form__check"><%= b.check_box %> <%= b.text %></label>
    <% end %>
  </fieldset>

  <fieldset class="form__field profile-form__group">
    <legend>Preferred methods</legend>
    <%= f.collection_check_boxes :preferred_methods, HuntStat::METHOD_OPTIONS, :itself, :itself do |b| %>
      <label class="form__check"><%= b.check_box %> <%= b.text %></label>
    <% end %>
  </fieldset>

  <div class="form__field">
    <label class="form__check">
      <%= f.check_box :notifications_enabled %>
      Email me about application deadlines and draw results
    </label>
  </div>

  <div class="profile-form__actions">
    <%= f.submit "Save profile", class: "button button--primary" %>
    <% if profile.new_record? %>
      <%= link_to "Skip for now", root_path, class: "button button--secondary" %>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 5: Create `app/views/profiles/new.html.erb`**

```erb
<div class="profile">
  <h1 class="profile__title">Set up your profile</h1>
  <p class="profile__subtitle">Takes a minute, and you can change it any time.</p>
  <%= render "form", profile: @profile %>
</div>
```

- [ ] **Step 6: Create `app/views/profiles/edit.html.erb`**

```erb
<div class="profile">
  <h1 class="profile__title">Edit your profile</h1>
  <%= render "form", profile: @profile %>
</div>
```

- [ ] **Step 7: Create `app/javascript/controllers/profile_form_controller.js`**

```js
import { Controller } from '@hotwired/stimulus'

// Shows a preference-points input only for species marked as a favorite.
// Hidden rows have their inputs disabled so they are not submitted.
export default class extends Controller {
  static targets = ['species', 'points']

  connect () {
    this.sync()
  }

  sync () {
    const checked = this.speciesTargets.filter(box => box.checked).map(box => box.value)
    this.pointsTargets.forEach(row => {
      const show = checked.includes(row.dataset.species)
      row.hidden = !show
      row.querySelectorAll('input').forEach(input => { input.disabled = !show })
    })
  }
}
```

- [ ] **Step 8: Run tests**

Run: `bin/rails test test/controllers/profiles_controller_test.rb`
Expected: PASS. If the "another user's points" test errors with `ActiveRecord::RecordNotFound` instead of passing, wrap that `patch` in `assert_raises(ActiveRecord::RecordNotFound)` (Rails scopes nested ids to the association, which is the desired protection) and keep the final data assertion.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/profiles_controller.rb app/views/profiles app/javascript/controllers/profile_form_controller.js test/controllers/profiles_controller_test.rb
git commit -m "feat: add skippable profile onboarding form" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Styling, docs, and full verification

**Files:**
- Create: `app/assets/stylesheets/components/_home.scss`, `app/assets/stylesheets/components/_profile.scss`
- Modify: `app/assets/stylesheets/application.scss`, `CLAUDE.md`

- [ ] **Step 1: Create `app/assets/stylesheets/components/_home.scss`**

```scss
@import "../abstracts/variables";
@import "../abstracts/typography";
@import "../themes/default";

.home,
.features {
  max-width: 960px;
  margin: 0 auto;
  padding: 2rem 1rem 4rem;
  background: $bg-page;
}

.home__title,
.features__title {
  margin: 0 0 0.5rem;
}

.home__subtitle,
.features__subtitle {
  margin: 0 0 2rem;
  color: $text-secondary;
}

.home__section,
.features__section {
  margin-top: 2.5rem;
}

.home__cards,
.features__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 1rem;
}

.home__card {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  text-decoration: none;
  color: inherit;

  &:hover {
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.1);
  }
}

.home__card-title {
  font-size: 1.25rem;
  font-weight: 600;
}

.home__card-meta {
  color: $text-secondary;
}

.home__card-cta {
  margin-top: auto;
  font-weight: 600;
}

.home__links {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
}

.banner {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem 1.5rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.75rem;
  background: #ffffff;

  p {
    margin: 0.25rem 0 0;
    color: $text-secondary;
  }
}
```

- [ ] **Step 2: Create `app/assets/stylesheets/components/_profile.scss`**

```scss
@import "../abstracts/variables";
@import "../abstracts/typography";
@import "../themes/default";

.profile {
  max-width: 640px;
  margin: 0 auto;
  padding: 2rem 1rem 4rem;
}

.profile__subtitle {
  color: $text-secondary;
}

.profile-form {
  [hidden] {
    display: none !important;
  }

  &__group {
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
    padding: 1rem;
    gap: 0.5rem;
  }

  &__hint {
    margin: 0;
    color: $text-secondary;
    font-size: 0.875rem;
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
  }
}

.form__check {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  margin-right: 1rem;
}
```

- [ ] **Step 3: Import them in `app/assets/stylesheets/application.scss`** (add after `@import "components/feedback";`)

```scss
@import "components/home";
@import "components/profile";
```

- [ ] **Step 4: Update `CLAUDE.md` Architecture section**

Replace the **Routes** bullet with:

```markdown
- **Routes** (`config/routes.rb`): root is `home#index` for everyone (Devise `authenticated`/`unauthenticated` roots); `HomeController` renders `home/personal` (greeting, profile, per-species dashboard links) for signed-in users and the marketing `home/index` otherwise. `/features` (public) lists current vs. future features. `resource :profile` (new/create/edit/update) is the skippable onboarding form; users without a profile see a "Finish your profile" banner and are never redirected. `hunt_stats` routes are declared but there is no `HuntStatsController` yet. `feedbacks#create` stores `Feedback` records.
- **Profile**: `User has_one :profile` (name, `residency_state`, derived `resident`, `favorite_species`, `states_of_interest`, `preferred_methods`, `notifications_enabled`) and `Profile has_many :preference_points` (species + 0–99 points). Species/methods validate against `HuntStat` constants.
```

- [ ] **Step 5: Compile assets and run the full suite**

Run: `bin/rails test`
Expected: PASS, 0 failures, 0 errors. A SCSS error here (e.g. an undefined variable) means the variable name is wrong; check `app/assets/stylesheets/themes/_default.scss` and fix the name.

- [ ] **Step 6: Manual smoke test** (start `bin/rails server` and `bin/webpack-dev-server`; Redis must be running)

1. Sign up a new user → lands on the home screen with the "Finish your profile" banner and three species cards.
2. Click "Set up profile". Ticking "Elk" under Favorite species reveals an Elk points input; unticking hides it.
3. Save → home screen greets by name; the Elk card shows the points and links to `/dashboard?filters[...]`, and the dashboard opens filtered.
4. Hit `/profile/edit`, change a value, save. Hit `/features` while signed out.

- [ ] **Step 7: Commit**

```bash
git add app/assets/stylesheets CLAUDE.md
git commit -m "style: home, features and profile styles; update CLAUDE.md" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```
