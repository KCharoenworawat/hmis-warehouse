FactoryGirl.define do
  factory :admin_role, class: 'Role' do
    name "admin"
    verb nil
    can_view_clients true
    can_edit_clients true
    can_view_all_reports true
    can_view_assigned_reports true
    can_assign_reports true
    can_view_censuses true
    can_view_census_details true
    can_edit_users true
    can_view_full_ssn true
    can_view_full_dob true
    can_view_hiv_status true
    can_view_dmh_status true
    can_view_imports true
    can_edit_roles true
    can_view_projects true
    can_edit_projects true
    can_edit_project_groups true
    can_view_organizations true
    can_edit_organizations true
    can_edit_data_sources true
    can_view_client_window true
    can_upload_hud_zips true
    can_edit_translations true
    can_manage_assessments true
    can_edit_anything_super_user true
    can_administer_health true
    can_edit_client_health true
    can_view_client_health true
    health_role false
    can_manage_config true
    can_manage_client_files true
    can_manage_window_client_files true
    can_edit_dq_grades true
    can_view_vspdat true
    can_edit_vspdat true
    can_edit_client_notes true
    can_edit_window_client_notes true
    can_track_anomalies true
    can_add_administrative_event true
  end

  factory :health_admin, class: 'Role' do
    name "health admin"
    verb nil
    health_role true
    can_view_assigned_reports true
    can_administer_health true
    can_edit_client_health true
    can_view_client_health true
  end

  factory :vispdat_viewer, class: 'Role' do
    name "vispdat viewer"
    can_view_vspdat true
  end

  factory :vispdat_editor, class: 'Role' do
    name "vispdat editor"
    can_view_vspdat true
    can_edit_vspdat true
  end

  factory :cohort_manager, class: 'Role' do
    name "cohort manager"
    can_manage_cohorts true
  end

  factory :cohort_client_editor, class: 'Role' do
    name 'cohort client editor'
    can_edit_assigned_cohorts true
  end

  factory :cohort_client_viewer, class: 'Role' do
    name 'cohort client viewer'
    can_view_assigned_cohorts true
  end

  factory :report_viewer, class: 'Role' do
    name 'cohort client viewer'
    can_view_all_reports true
  end

  factory :assigned_report_viewer, class: 'Role' do
    name 'cohort client viewer'
    can_view_assigned_reports true
  end

  factory :assigned_ds_viewer, class: 'Role' do
    name 'ds viewer'
    can_see_clients_in_window_for_assigned_data_sources true
  end
end
