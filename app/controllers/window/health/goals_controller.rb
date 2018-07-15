module Window::Health
  class GoalsController < IndividualPatientController

    before_action :set_client
    before_action :set_hpc_patient
    before_action :set_careplan

    include PjaxModalController
    include WindowClientPathGenerator
    include HealthGoal

    def after_path
      polymorphic_path([:edit] + careplan_path_generator, id: @careplan)
    end

    def goal_form_path
      if @goal.new_record?
        polymorphic_path(careplan_path_generator + [:goals])
      else
        polymorphic_path(careplan_path_generator + [:goal], id: @goal.id)
      end
    end
    helper_method :goal_form_path

    def new_goal_path
      polymorphic_path([:new] + careplan_path_generator + [:goal], careplan_id: @careplan.id)
    end
    helper_method :new_goal_path

    def edit_goal_path(goal)
      polymorphic_path([:edit] + careplan_path_generator + [:goal], careplan_id: @careplan.id, id: goal.id)
    end
    helper_method :edit_goal_path

    def delete_goal_path(goal)
      polymorphic_path(careplan_path_generator + [:goal], careplan_id: @careplan.id, id: goal.id)
    end
    helper_method :delete_goal_path

    def set_careplan
      @careplan = careplan_source.find(params[:careplan_id].to_i)
    end

    def careplan_source
      Health::Careplan
    end

    def flash_interpolation_options
      { resource_name: 'Goal' }
    end
  end
end