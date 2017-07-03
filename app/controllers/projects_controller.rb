
class ProjectsController < ApplicationController
  before_action :require_can_view_projects!
  before_action :set_project, only: [:show]
  
  def index
    # search
    @projects = if params[:q].present?
      project_source.text_search(params[:q])
    else
      project_scope
    end
    # sort / paginate
    at = project_scope.arel_table
    column = at[sort_column.to_sym]
    if sort_column == 'organization_id'
      column = organization_source.arel_table[:OrganizationName]
    end
    sort = column.send(sort_direction)
    # Filter
    if params[:project].present?
      @projects = @projects.filter(filter_columns)
    end
    @projects = @projects
      .includes(:organization)
      .preload(:sites)
      .preload(:inventories)
      .order(sort)
      .page(params[:page]).per(50)
  end

  def show
    @clients = @project.service_history
      .where(record_type: 'entry')
      .preload(:client)
      .page(params[:page]).per(25)
  end

  private def project_scope
    project_source.all
  end

  private def client_source
    GrdaWarehouse::Hud::Client
  end

  private def project_source
    GrdaWarehouse::Hud::Project.viewable_by current_user
  end

  private def organization_source
    GrdaWarehouse::Hud::Organization.viewable_by current_user
  end

  private def service_history_scope
    GrdaWarehouse::ServiceHistory.service
  end

  private def set_project
    @project = project_source.find(params[:id].to_i)
  end

  private def sort_columns
    [:ProjectName, :ProjectType, :data_source_id]
  end

  # whitelist filter-able columns
  private def filter_columns
    params.require(:project).
      permit(ProjectType: [], OrganizationID: [], data_source_id: [])
  end

  def sort_column
    project_source.column_names.include?(params[:sort]) ? params[:sort] : 'ProjectName'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end
end