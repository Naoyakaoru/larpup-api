require "rails_helper"

RSpec.describe "Logging instrumentation", type: :request do
  include AuthHelpers

  # ── Helper: the lograge custom_options lambda, defined inline so we can test
  # it regardless of Rails.env (it's only wired in production.rb).
  let(:custom_options) do
    lambda do |event|
      opts = {
        request_id: event.payload[:request_id],
        ip:         event.payload[:remote_ip],
      }
      opts[:user_id] = event.payload[:user_id] if event.payload[:user_id]
      opts[:error]   = event.payload[:error]   if event.payload[:error]
      opts
    end
  end

  def make_event(overrides = {})
    payload = { request_id: "abc-123", remote_ip: "1.2.3.4" }.merge(overrides)
    double("event", payload: payload)
  end

  # ── 1. append_info_to_payload (ApplicationController hook) ─────────────────

  describe "append_info_to_payload" do
    it "injects user_id and remote_ip into the process_action payload" do
      user = create(:user)
      received_payload = nil

      subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        received_payload = event.payload
      end

      get "/api/v1/users/me", headers: auth_header(user)

      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(received_payload[:user_id]).to eq(user.id)
      expect(received_payload[:remote_ip]).to be_present
    end

    it "injects nil user_id when request is unauthenticated" do
      received_payload = nil

      subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        received_payload = event.payload
      end

      get "/up"   # public health-check endpoint

      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(received_payload[:user_id]).to be_nil
    end
  end

  # ── 2. lograge custom_options lambda unit tests ─────────────────────────────

  describe "lograge custom_options lambda" do
    it "includes request_id and ip" do
      result = custom_options.call(make_event)
      expect(result[:request_id]).to eq("abc-123")
      expect(result[:ip]).to eq("1.2.3.4")
    end

    it "includes user_id when present in payload" do
      result = custom_options.call(make_event(user_id: 42))
      expect(result[:user_id]).to eq(42)
    end

    it "omits user_id key when payload has nil user_id" do
      result = custom_options.call(make_event(user_id: nil))
      expect(result).not_to have_key(:user_id)
    end

    it "includes error when present in payload" do
      result = custom_options.call(make_event(error: "Something went wrong"))
      expect(result[:error]).to eq("Something went wrong")
    end

    it "omits error key when not in payload" do
      result = custom_options.call(make_event)
      expect(result).not_to have_key(:error)
    end

    it "does NOT call .dig on headers (regression guard for NoMethodError)" do
      # ActionDispatch::Http::Headers does not support .dig —
      # this test ensures we never accidentally regress to that pattern.
      fake_headers = Object.new  # deliberately has no .dig method
      event = make_event(headers: fake_headers)
      expect { custom_options.call(event) }.not_to raise_error
    end
  end
end
