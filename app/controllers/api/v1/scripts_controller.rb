module Api
  module V1
    class ScriptsController < ApplicationController
      skip_before_action :authenticate!, only: [ :index, :show ]
      before_action :set_current_user_optional, only: [ :index, :show ]
      before_action :require_admin!, only: [ :create, :update ]

      def index
        page = (params[:page] || 1).to_i
        if page > 1 && !current_user
          return render json: { error: "Unauthorized" }, status: :unauthorized
        end

        scripts = Script.active.where(status: :approved)
        scripts = scripts.where(difficulty: params[:difficulty]) if params[:difficulty].in?(%w[easy medium hard])
        if params[:genres].present?
          genre_ids = params[:genres].split(",").map(&:to_i)
          scripts = scripts.where("genres @> ARRAY[?]::integer[]", genre_ids)
        end
        scripts = scripts.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?

        per_page = 36
        scripts = scripts.order(Arel.sql("(metadata->>'qiandao_wish_count')::int DESC NULLS LAST"), created_at: :desc).limit(per_page + 1).offset((page - 1) * per_page)

        has_more = scripts.length > per_page
        render json: {
          scripts: scripts.take(per_page).map { |s| ScriptSerializer.new(s, url_helper: method(:url_for)).as_json },
          has_more: has_more
        }
      end

      def show
        script = Script.active.find(params[:id])
        render json: ScriptSerializer.new(script, url_helper: method(:url_for), include_metadata: current_user&.is_admin?).as_json
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
