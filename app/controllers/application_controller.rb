# frozen_string_literal: true

require "uri"

class ApplicationController < ActionController::Base
  CLERK_VOTE_SIGN_IN_ALERT = "Please sign in to vote."

  include Clerk::Authenticatable

  helper_method :clerk_sign_in_url, :clerk_sign_up_url, :clerk_sign_out_url

  protected

  def command_bus
    Rails.configuration.command_bus
  end

  def require_clerk_session!
    return if clerk.user?

    # Clerk Account Portal is another host — Rails 7.1+ requires explicit consent.
    redirect_to clerk_sign_in_url, alert: CLERK_VOTE_SIGN_IN_ALERT, allow_other_host: true
  end

  # Account Portal needs redirect_url or users hit /default-redirect; must be a full URL (https://…).
  # https://clerk.com/docs/guides/account-portal/direct-links
  def clerk_sign_in_url
    clerk_account_portal_url(:sign_in)
  end

  def clerk_sign_up_url
    clerk_account_portal_url(:sign_up)
  end

  def clerk_sign_out_url
    clerk_account_portal_url(:sign_out)
  end

  private

  def clerk_account_portal_url(kind)
    base =
      case kind
      when :sign_in
        clerk_sdk_url(:sign_in_url, "CLERK_SIGN_IN_URL")
      when :sign_up
        clerk_sdk_url(:sign_up_url, "CLERK_SIGN_UP_URL")
      when :sign_out
        clerk_sdk_url(:sign_out_url, "CLERK_SIGN_OUT_URL")
      end

    append_clerk_redirect_url(base)
  end

  def clerk_sdk_url(method, env_key)
    if clerk.respond_to?(method)
      url = clerk.public_send(method)
      return url if url.present?
    end
    ENV.fetch(env_key)
  end

  def append_clerk_redirect_url(base)
    return base if base.blank?
    return base unless respond_to?(:request) && request.present?

    after_auth = "#{request.base_url.chomp('/')}#{root_path}"
    uri = URI.parse(base)
    params = Rack::Utils.parse_query(uri.query.to_s)
    params["redirect_url"] = after_auth
    uri.query = Rack::Utils.build_query(params).presence
    uri.to_s
  rescue URI::InvalidURIError
    joiner = base.include?("?") ? "&" : "?"
    "#{base}#{joiner}redirect_url=#{CGI.escape(after_auth)}"
  end
end
