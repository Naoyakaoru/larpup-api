module Api
  module V1
    class UserConsentsController < ApplicationController
      # POST /api/v1/user_consents
      def create
        consent = current_user.user_consents.new(consent_params)
        consent.ip_address = request.remote_ip
        consent.user_agent = request.user_agent
        consent.accepted_at = Time.current

        if consent.save
          render json: consent_json(consent), status: :created
        else
          render json: { errors: consent.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/user_consents
      def index
        consents = current_user.user_consents.order(accepted_at: :desc)
        render json: consents.map { |c| consent_json(c) }
      end

      private

      def consent_params
        params.permit(:consent_type, :consent_version, :accepted, :source)
      end

      def consent_json(consent)
        {
          id:               consent.id,
          consent_type:     consent.consent_type,
          consent_version:  consent.consent_version,
          accepted:         consent.accepted,
          accepted_at:      consent.accepted_at,
          source:           consent.source,
          ip_address:       consent.ip_address
        }
      end
    end
  end
end
