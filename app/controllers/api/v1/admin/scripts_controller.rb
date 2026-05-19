
module Api
  module V1
    module Admin
      class ScriptsController < ApplicationController
        before_action :require_admin!
        before_action :set_script, only: %i[approve reject destroy cover_import cover_delete]

        def index
          scripts = Script.unscope(where: :deleted_at)
                         .order(Arel.sql("CASE WHEN deleted_at IS NOT NULL THEN 3 WHEN status = 'pending' THEN 0 WHEN status = 'approved' THEN 1 ELSE 2 END"), :id)
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
          result = QiandaoSearchService.call(title)
          if result
            render json: result
          else
            render json: { error: "Script not found" }, status: :not_found
          end
        rescue => e
          Rails.logger.error("Autofill error: #{e.class} #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          render json: { error: "Lookup failed: #{e.message}" }, status: :unprocessable_entity
        end

        def destroy
          @script.update_column(:deleted_at, Time.current)
          head :no_content
        end

        def cover_delete
          return render json: { error: "No cover attached" }, status: :unprocessable_entity unless @script.cover_image.attached?
          @script.cover_image.purge
          render json: ScriptSerializer.new(@script.reload, url_helper: method(:url_for)).as_json
        end

        def bulk_import
          rows = params.require(:scripts)
          created = 0
          skipped = 0
          errors = []

          existing_scripts = Script.where(title: rows.map { |r| r[:title] }).index_by(&:title)

          rows.each_with_index do |row, i|
            meta = {}
            meta[:qiandao_id] = row[:qiandao_id] if row[:qiandao_id].present?
            meta[:qiandao_rating] = row[:rating].to_f if row[:rating].present?
            meta[:qiandao_wish_count] = row[:wish_count].to_i if row[:wish_count].present?
            meta[:qiandao_cover_id] = row[:cover_image_id] if row[:cover_image_id].present?

            if existing_script = existing_scripts[row[:title]]
              # Update existing metadata
              updated_meta = existing_script.metadata.merge(meta)
              if existing_script.update(metadata: updated_meta)
                skipped += 1 # consider it "skipped for creation" but updated
              else
                errors << { index: i, title: row[:title], messages: existing_script.errors.full_messages }
              end
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
