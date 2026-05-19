require "open3"

module Api
  module V1
    module Admin
      class ScriptsController < ApplicationController
        before_action :require_admin!
        before_action :set_script, only: %i[approve reject destroy cover_import]

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

        def cover_import
          cover_id = @script.metadata&.dig("qiandao_cover_id")
          return render json: { error: "No cover data available" }, status: :unprocessable_entity if cover_id.blank?
          return render json: { error: "Cover already attached" }, status: :unprocessable_entity if @script.cover_image.attached?

          cdn_base = "https://treasure.qiandaocdn.com/treasure/images"
          url = "#{cdn_base}/#{cover_id}!lfit_w600"
          ext = File.extname(cover_id).downcase
          content_type = ext == ".png" ? "image/png" : "image/jpeg"

          begin
            io = URI.open(url, read_timeout: 15, open_timeout: 5)
            @script.cover_image.attach(io: io, filename: cover_id, content_type: content_type)
            render json: ScriptSerializer.new(@script, url_helper: method(:url_for)).as_json
          rescue => e
            render json: { error: "Failed to download cover" }, status: :unprocessable_entity
          end
        end

        def autofill
          title = params.require(:title)
          script_root = Rails.root
          python = script_root.join(".venv/bin/python")
          lookup_script = script_root.join("scripts/qiandao_lookup.py")

          output, status = Open3.capture2(python.to_s, lookup_script.to_s, title, chdir: script_root.join("scripts").to_s)
          return render json: { error: "Lookup failed" }, status: :unprocessable_entity unless status.success?

          result = JSON.parse(output.strip)
          if result["error"]
            render json: { error: "Script not found" }, status: :not_found
          else
            render json: result
          end
        rescue => e
          render json: { error: "Lookup failed" }, status: :unprocessable_entity
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
