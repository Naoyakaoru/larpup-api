module Api
  module V1
    class ScriptsController < ApplicationController
      skip_before_action :authenticate!, only: [ :index, :show ]

      def index
        scripts = Script.all
        scripts = scripts.where(difficulty: params[:difficulty]) if params[:difficulty].present?
        scripts = scripts.where("genres @> ARRAY[?]::integer[]", params[:genre].to_i) if params[:genre].present?
        render json: scripts.map { |s| script_json(s) }
      end

      def show
        script = Script.find(params[:id])
        render json: script_json(script)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Script not found" }, status: :not_found
      end

      def create
        script = Script.new(script_params)
        if script.save
          render json: script_json(script), status: :created
        else
          render json: { errors: script.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        script = Script.find(params[:id])
        if script.update(script_params)
          render json: script_json(script)
        else
          render json: { errors: script.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Script not found" }, status: :not_found
      end

      private

      def script_params
        params.permit(:title, :difficulty, :description, :male_slots, :female_slots, :any_slots, genres: [])
      end

      def script_json(script)
        {
          id: script.id,
          title: script.title,
          genres: script.genre_labels,
          difficulty: script.difficulty,
          male_slots: script.male_slots,
          female_slots: script.female_slots,
          any_slots: script.any_slots,
          total_slots: script.total_slots,
          description: script.description
        }
      end
    end
  end
end
