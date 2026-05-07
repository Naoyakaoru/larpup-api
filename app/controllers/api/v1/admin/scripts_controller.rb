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
      end
    end
  end
end
