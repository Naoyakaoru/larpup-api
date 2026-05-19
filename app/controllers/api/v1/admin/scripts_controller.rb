module Api
  module V1
    module Admin
      class ScriptsController < ApplicationController
        before_action :require_admin!
        before_action :set_script, only: %i[approve reject destroy]

        def index
          scripts = Script.order(Arel.sql("CASE status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END"), :id)
          scripts = scripts.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?

          total = scripts.count
          page = (params[:page] || 1).to_i
          per_page = 20
          scripts = scripts.limit(per_page).offset((page - 1) * per_page)

          render json: {
            scripts: scripts.map { |s| ScriptSerializer.new(s, url_helper: method(:url_for)).as_json },
            total: total,
            page: page,
            total_pages: (total.to_f / per_page).ceil,
            pending_count: Script.where(status: :pending).count
          }
        end

        def approve
          @script.update!(status: :approved)
          render json: ScriptSerializer.new(@script, url_helper: method(:url_for)).as_json
        end

        def reject
          @script.update!(status: :rejected)
          render json: ScriptSerializer.new(@script, url_helper: method(:url_for)).as_json
        end

        def destroy
          @script.update_column(:deleted_at, Time.current)
          head :no_content
        end

        def bulk_import
          rows = params.require(:scripts)
          created = 0
          skipped = 0
          errors = []

          existing_titles = Script.where(title: rows.map { |r| r[:title] }).pluck(:title).to_set

          rows.each_with_index do |row, i|
            if existing_titles.include?(row[:title])
              skipped += 1
              next
            end

            meta = {}
            meta[:qiandao_id] = row[:qiandao_id] if row[:qiandao_id].present?
            meta[:qiandao_rating] = row[:rating].to_f if row[:rating].present?
            meta[:qiandao_cover_id] = row[:cover_image_id] if row[:cover_image_id].present?

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
              metadata: meta,
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

        private

        def set_script
          @script = Script.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Script not found" }, status: :not_found
        end
      end
    end
  end
end
