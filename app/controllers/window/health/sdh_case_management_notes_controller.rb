module Window::Health
  class SdhCaseManagementNotesController < IndividualPatientController

    include PjaxModalController
    include WindowClientPathGenerator
    include HealthFileController
    
    before_action :require_can_edit_patient_items_for_own_agency!, only: [:new, :create, :edit, :update]
    before_action :set_client
    before_action :set_hpc_patient
    before_action :load_template_activity, only: [:edit, :update]
    before_action :load_note, only: [:show, :edit, :update, :download, :remove_file, :destroy]
    before_action :set_upload_object, only: [:edit, :update, :remove_file, :download]
    
    def show
      render :show
    end

    def new
      last_form = @patient.sdh_case_management_notes.last_form
      @note = @patient.sdh_case_management_notes.
        build(
          user: current_user,
          completed_on: DateTime.current,
          housing_placement_date: last_form&.housing_placement_date,
          client_phone_number: last_form&.client_phone_number)
      @note.activities.build
      @note.save(validate: false)
      redirect_to polymorphic_path([:edit] + sdh_case_management_note_path_generator, client_id: @client.id, id: @note.id)
    end

    def edit
      @activities = @note.activities.sort_by(&:id)
      unless @note.health_file
        @note.build_health_file
      end
      respond_with @note
    end

    def update
      @activity_count = @note.activities.size
      @note.assign_attributes(note_params.merge(updated_at: Time.now))
      if params[:commit] == 'Save Case Note'
        if @note.health_file&.new_record?
          @note.health_file.set_calculated!(current_user.id, @client.id)
        end
        @note.save
      else
        @note.save(validate: false)
      end
      @noteAdded = (@activity_count != @note.activities.size)
      @activities = @note.activities.sort_by(&:id)
      respond_with @note, location: polymorphic_path(careplans_path_generator)
    end

    def destroy
      @note.destroy!
      redirect_to polymorphic_path(careplans_path_generator)
    end

    def form_url(opts = {})
      if @note.new_record?
        opts = opts.merge({client_id: @client.id})
        path = sdh_case_management_notes_path_generator
      else
        opts = opts.merge({client_id: @client.id, id: @note.id})
        path = sdh_case_management_note_path_generator
      end
      polymorphic_path(path, opts)
    end
    helper_method :form_url

    def display_note_object
      result = []
      result.push(@note.display_basic_info_section)
      result.push(@note.display_basic_note_section)
      result.push(@note.display_note_details_section)
      result.push({title: 'Qualifying Activities'})
      if @note.activities.any?
        @note.activities.each_with_index do |activity, index|
          result.push(activity.display_sections(index))
        end
      else
        result.push({values: [{value: 'No Activities'}]})
      end
      result.push(@note.display_additional_questions_section)
      result
    end
    helper_method :display_note_object

    private

    def set_upload_object
      @upload_object = @note
      if action_name == 'remove_file'
        @location = polymorphic_path([:edit] + sdh_case_management_note_path_generator, client_id: @client.id, id: @note.id)
      end
      @download_path = @upload_object.downloadable? ? polymorphic_path([:download] + sdh_case_management_note_path_generator, client_id: @client.id, id: @note.id ) : 'javascript:void(0)'
      @download_data = @upload_object.downloadable? ? {} : {confirm: 'Form errors must be fixed before you can download this file.'}
      @remove_path = @upload_object.downloadable? ? polymorphic_path([:remove_file] + sdh_case_management_note_path_generator, client_id: @client.id, id: @note.id) : '#'
    end

    def load_note
      @note = Health::SdhCaseManagementNote.find(params[:id])
    end

    def load_template_activity
      @template_activity = Health::QualifyingActivity.new(user: current_user, user_full_name: current_user.name)
    end

    def clean_note_params!
      # NOTE: Remove COPY from activities_attributes -- if this is present in params we get unpermitted params
      # Let me know if there is a better solution @meborn
      # COPY is used to add activities via js see health/sdh_case_management_note/form_js addActivity
      (params[:health_sdh_case_management_note][:activities_attributes]||{}).reject!{|k,v| k == "COPY"}
      # remove :_destroy on ajax
      # remove health_file on ajax
      if params[:commit] != 'Save Case Note'
        params[:health_sdh_case_management_note].except!(:health_file_attributes)
      end
      if params[:commit] != 'Save Case Note' && params[:commit] != 'Remove Activity'
        (params[:health_sdh_case_management_note][:activities_attributes]||{}).keys.each do |key|
          (params[:health_sdh_case_management_note][:activities_attributes]||{})[key].reject!{|k,v| k == "_destroy"}
        end
      end
      # remove empty element from topics array
      (params[:health_sdh_case_management_note][:topics]||[]).reject!{|v| v.blank?}
      # remove empty element from client action array
      (params[:health_sdh_case_management_note][:client_action]||[]).reject!{|v| v.blank?}
    end

    def add_calculated_params_to_activities!(permitted_params)
      (permitted_params[:activities_attributes]||{}).keys.each do |key|
        permitted_params[:activities_attributes][key].merge!({
          user_id: current_user.id,
          user_full_name: current_user.name,
          patient_id: @patient.id
        })
      end
      permitted_params
    end

    def note_params
      clean_note_params!
      permitted_params = params.require(:health_sdh_case_management_note).permit(
        :title,
        :total_time_spent_in_minutes,
        :date_of_contact,
        :place_of_contact,
        :place_of_contact_other,
        :housing_status,
        :housing_status_other,
        :housing_placement_date,
        :client_action_medication_reconciliation_clinician,
        :notes_from_encounter,
        :client_phone_number,
        :completed_on,
        client_action: [],
        topics: [],
        activities_attributes: [
          :id,
          :mode_of_contact,
          :mode_of_contact_other,
          :reached_client,
          :reached_client_collateral_contact,
          :activity,
          :date_of_activity,
          :follow_up,
          :_destroy
        ],
        health_file_attributes: [
          :id,
          :file,
          :file_cache,
          :note
        ]
      )
      add_calculated_params_to_activities!(permitted_params)
    end

    def flash_interpolation_options
      { resource_name: 'Case Management Note' }
    end

    protected def title_for_show
      "#{@client.name} - Health - Case Management Notes"
    end
  end
end