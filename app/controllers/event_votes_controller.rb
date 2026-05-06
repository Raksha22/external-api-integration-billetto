# frozen_string_literal: true

class EventVotesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :vote_event_not_found

  before_action :require_clerk_session!
  before_action :set_event

  def create
    cmd = Guidelines::RecordEventVote.new(
      event_external_id: @event.external_id,
      clerk_user_id: clerk.user_id.to_s,
      direction: direction_param
    )
    unless cmd.valid?
      redirect_to events_path, alert: cmd.errors.full_messages.to_sentence and return
    end

    command_bus.call(cmd)
    redirect_to events_path, notice: "Vote recorded."
  rescue Command::UnknownCommandError => e
    redirect_to events_path, alert: e.message
  end

  private

  def set_event
    @event = Guidelines::Event.find(params[:event_id])
  end

  def direction_param
    params[:direction].to_s.downcase
  end

  def vote_event_not_found
    redirect_to events_path, alert: "Event not found."
  end
end
