module WarehouseReports::Project
  class DataQualitiesController < ApplicationController
    before_action :require_can_view_reports!

    before_action :set_projects

    def show
      @range = DateRange.new()
    end

    def create
      errors = []
      @generate = generate_param == 1
      @email = email_param == 1
      if date_range_params[:start].blank? || date_range_params[:end].blank?
        errors << 'A date range is required'
      end
      @range = DateRange.new(date_range_params)
      @range.validate
      begin
        @project_ids = project_params
      rescue ActionController::ParameterMissing => e
        errors << 'At least one project must be selected'
      end
      if errors.any?
        flash[:error] = errors.join('<br />'.html_safe)
        render action: :show
      else
        # kick off report generation
        @project_ids.each do |project_id|
          if @generate
            report = report_scope.create(project_id: project_id, start: @range.start, end: @range.end)
          else
            report = report_scope.
              where(project_id: project_id).
              order(id: :desc).first_or_initialize
          end
          Reporting::RunProjectDataQualityJob.perform_later(report_id: report.id, generate: @generate, send_email: @email)
        end
        redirect_to action: :show
      end
    end

    def download
      @report = []
      # FIXME, these should be gathered in one query that 
      # fetches the most recent report for each project that 
      @projects.each do |_, projects|
        projects.each do |project|
          last_report = project.data_quality_reports.complete.last 
          @report << last_report if last_report.present?
        end
      end
      @report
      # FIXME: Filename isn't working
      render filename: "project_data_quality_report #{Date.today}.xlsx"
    end

    def generate_param
      params.permit(project_data_quality: [:generate])[:project_data_quality][:generate].try(:to_i)
    end

    def email_param
      params.permit(project_data_quality: [:email])[:project_data_quality][:email].try(:to_i)
    end

    def project_params
      params.require(:project).keys.map(&:to_i)
    end

    def date_range_params
      params.require(:project_data_quality).
        permit([:start, :end])
    end

    def project_scope
      GrdaWarehouse::Hud::Project.all
    end

    def report_scope
      GrdaWarehouse::WarehouseReports::Project::DataQuality::VersionOne
    end

    def set_projects
      @projects = project_scope.includes(:organization, :data_source).
        order(data_source_id: :asc, OrganizationID: :asc).
        preload(:project_contacts, :data_quality_reports).
        group_by{ |m| [m.data_source.short_name, m.organization]}
    end
  end
end