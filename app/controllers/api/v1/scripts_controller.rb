module Api
  module V1
    class ScriptsController < ApplicationController
      skip_before_action :authenticate!, only: [ :index, :show ]
      before_action :require_admin!, only: [ :create, :update ]

      def index
        scripts = Script.where(status: :approved)
        scripts = scripts.where(difficulty: params[:difficulty]) if params[:difficulty].present?
        scripts = scripts.where("genres @> ARRAY[?]::integer[]", params[:genre].to_i) if params[:genre].present?
        scripts = scripts.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?
        
        page = (params[:page] || 1).to_i
        per_page = 36
        scripts = scripts.order(id: :desc).limit(per_page + 1).offset((page - 1) * per_page)
        
        has_more = scripts.length > per_page
        render json: {
          scripts: scripts.take(per_page).map { |s| ScriptSerializer.new(s, url_helper: method(:url_for)).as_json },
          has_more: has_more
        }
      end

      def show
        script = Script.find(params[:id])
        render json: ScriptSerializer.new(script, url_helper: method(:url_for)).as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Script not found" }, status: :not_found
      end

      def create
        script = Script.new(script_params)
        if script.save
          render json: ScriptSerializer.new(script, url_helper: method(:url_for)).as_json, status: :created
        else
          render json: { errors: script.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        script = Script.find(params[:id])
        if script.update(script_params)
          render json: ScriptSerializer.new(script, url_helper: method(:url_for)).as_json
        else
          render json: { errors: script.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Script not found" }, status: :not_found
      end

      private

      def script_params
        params.permit(:title, :difficulty, :description, :male_slots, :female_slots, :any_slots, :duration, :cover_image, genres: [])
      end
    end
  end
end
