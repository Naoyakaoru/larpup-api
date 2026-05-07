module Api
  module V1
    module Admin
      class ScriptsController < ApplicationController
        before_action :require_admin!

        def index
          scripts = Script.order(Arel.sql("CASE status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END"), :id)
          render json: scripts.map { |s| ScriptSerializer.new(s, url_helper: method(:url_for)).as_json }
        end

        def approve
          script = Script.find(params[:id])
          script.update!(status: :approved)
          render json: ScriptSerializer.new(script, url_helper: method(:url_for)).as_json
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Script not found" }, status: :not_found
        end

        def reject
          script = Script.find(params[:id])
          script.update!(status: :rejected)
          render json: ScriptSerializer.new(script, url_helper: method(:url_for)).as_json
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Script not found" }, status: :not_found
        end

        def bulk_import
          rows = params.require(:scripts)
          created = 0
          skipped = 0
          errors = []

          rows.each_with_index do |row, i|
            if Script.exists?(title: row[:title])
              skipped += 1
              next
            end

            script = Script.new(
              title: row[:title],
              difficulty: row[:difficulty],
              genres: Array(row[:genres]),
              male_slots: row[:male_slots].to_i,
              female_slots: row[:female_slots].to_i,
              any_slots: row[:any_slots].to_i,
              duration: row[:duration].presence,
              description: row[:description].presence || "",
              publisher: row[:publisher].presence,
              status: :approved,
            )
            if script.save
              created += 1
            else
              errors << { index: i, title: row[:title], messages: script.errors.full_messages }
            end
          end

          render json: { created: created, skipped: skipped, errors: errors }
        end
      end
    end
  end
end
