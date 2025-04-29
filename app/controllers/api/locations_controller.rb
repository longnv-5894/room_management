module Api
  class LocationsController < ApplicationController
    before_action :require_login
    
    # Return cities for a given country
    def cities
      @cities = City.where(country_id: params[:country_id]).order(:name)
      render json: @cities.map { |city| { id: city.id, name: city.name } }
    end
    
    # Return districts for a given city
    def districts
      @districts = District.where(city_id: params[:city_id]).order(:name)
      render json: @districts.map { |district| { id: district.id, name: district.name } }
    end
    
    # Return wards for a given district
    def wards
      @wards = Ward.where(district_id: params[:district_id]).order(:name)
      render json: @wards.map { |ward| { id: ward.id, name: ward.name } }
    end
    
    private
    
    def require_login
      unless current_user
        render json: { error: 'Authentication required' }, status: :unauthorized
      end
    end
  end
end