module Cohorts
  class ClientNotesController < ApplicationController
    include PjaxModalController
    include CohortAuthorization
    before_action :require_can_access_cohort!
    before_action :set_note, only: [:destroy]
    before_action :set_cohort_and_client

    def index
    end

    def new
      @note = note_source.new(client_id: @cohort_client.client_id)
    end

    def create
      begin
        @note = note_source.create(
          note_params.merge(
            {
              client_id: @cohort_client.client_id,
              user_id: current_user.id,
            }
          )
        )
        @cohort_client.touch
        respond_with(@note, location: cohort_path(id: params[:cohort_id].to_i))
      rescue
        @note = {error: 'Failed to create a note.'}
      end
    end

    def destroy
      if @note.destroyable_by current_user
        @note.destroy
        respond_with(@note, location: cohort_path(id: params[:cohort_id].to_i))
      else
        flash[:error] = 'Unable to destroy note'
        @note = {error: 'Unable to destroy note.'}
        respond_with(@cohort, location: cohort_path(@cohort))
      end
    end

    def set_cohort_and_client
      @cohort = GrdaWarehouse::Cohort.find(params[:cohort_id].to_i)
      @cohort_client = @cohort.cohort_clients.find(params[:cohort_client_id].to_i)
    end

    def note_params
      params.require(:grda_warehouse_client_notes_cohort_note).permit(
          :note
      )
    end

    def note_source
      GrdaWarehouse::ClientNotes::CohortNote
    end

    def set_note
      @note = note_source.find(params[:id].to_i)
    end

    def cohort_id
      params[:cohort_id].to_i
    end

    def flash_interpolation_options
      { resource_name: "Note for #{@note.client.name}" }
    end
  end
end
