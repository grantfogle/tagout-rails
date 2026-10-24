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
