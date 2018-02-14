require 'rails_helper'

RSpec.describe Exporters::HmisSixOneOne::Base, type: :model do
  let!(:data_source) { create :source_data_source, id: 2}
  let!(:user) {create :user}
  let!(:projects) { create_list :hud_project, 5, data_source_id: data_source.id }
  let!(:project_group) { create :project_group, name: 'P Group', projects: projects }
  let!(:organizations) { create_list :hud_organization, 5, data_source_id: data_source.id }
  let!(:inventories) { create_list :hud_inventory, 5, data_source_id: data_source.id }
  let!(:affiliations) { create_list :hud_affiliation, 5, data_source_id: data_source.id }
  let!(:geographies) { create_list :hud_geography, 5, data_source_id: data_source.id }
  let!(:project_cocs) { create_list :hud_project_coc, 5, data_source_id: data_source.id }
  let!(:funders) { create_list :hud_funder, 5, data_source_id: data_source.id }

  # Project Related
  # 'Affiliation.csv' => affiliation_source,
  # 'Funder.csv' => funder_source,
  # 'Inventory.csv' => inventory_source,
  # 'Organization.csv' => organization_source,
  # 'Geography.csv' => geography_source,
  # 'ProjectCoC.csv' => project_coc_source,
  
  # Enrollment Related
  # 'Disabilities.csv' => disability_source,
  # 'EmploymentEducation.csv' => employment_education_source,
  # 'EnrollmentCoC.csv' => enrollment_coc_source,
  # 'Exit.csv' => exit_source,
  # 'HealthAndDV.csv' => health_and_dv_source,
  # 'IncomeBenefits.csv' => income_benefits_source,
  # 'Services.csv' => service_source,
  
  #  Other
  # 'Export.csv' => export_source,
  # 'Client.csv' => client_source,
  # 'Enrollment.csv' => enrollment_source,
  # 'Project.csv' => project_source,
  
  let(:exporter) {
    Exporters::HmisSixOneOne::Base.new(
      start_date: 1.week.ago.to_date, 
      end_date: Date.today, 
      projects: project_group.project_ids, 
      period_type: 3,
      directive: 3,
      user_id: user.id
    )
  }
  class ProjectRelatedTests
    TESTS = [
      { 
        list: :organizations,
        klass: GrdaWarehouse::Export::HMISSixOneOne::Organization,
        export_method: :export_organizations,
      },
      { 
        list: :inventories,
        klass: GrdaWarehouse::Export::HMISSixOneOne::Inventory,
        export_method: :export_inventories,
      },
      { 
        list: :affiliations,
        klass: GrdaWarehouse::Export::HMISSixOneOne::Affiliation,
        export_method: :export_affiliations,
      },
      { 
        list: :geographies,
        klass: GrdaWarehouse::Export::HMISSixOneOne::Geography,
        export_method: :export_geographies,
      },
      { 
        list: :project_cocs,
        klass: GrdaWarehouse::Export::HMISSixOneOne::ProjectCoc,
        export_method: :export_project_cocs,
      },
      { 
        list: :funders,
        klass: GrdaWarehouse::Export::HMISSixOneOne::Funder,
        export_method: :export_funders,
      },
    ]
  end

  describe 'When exporting project related item' do
    before(:each) do
      exporter.create_export_directory()
      exporter.set_time_format()
      exporter.setup_export()
    end
    after(:each) do
      exporter.remove_export_files()
      exporter.reset_time_format()
    end
    describe 'when exporting projects' do
      before(:each) do
        exporter.export_projects()
        @project_class = GrdaWarehouse::Export::HMISSixOneOne::Project
      end
      it 'project scope should find five projects' do
        expect( exporter.project_scope.count ).to eq 5
      end
      it 'creates one CSV file' do
        expect(File.exists?(csv_file_path(@project_class))).to be true
      end
      it 'adds five rows to the project CSV file' do
        csv_projects = CSV.read(csv_file_path(@project_class), headers: true)
        expect(csv_projects.count).to eq 5
      end
      it 'project from CSV file should contain all project names' do
        csv = CSV.read(csv_file_path(@project_class), headers: true)
        csv_project_names = csv.map{|m| m['ProjectName']}
        expect(csv_project_names).to eq projects.map(&:ProjectName)
      end
      it 'ProjectID from CSV should contain all project IDs' do
        csv = CSV.read(csv_file_path(@project_class), headers: true)
        csv_project_ids = csv.map{|m| m['ProjectID']}
        expect(csv_project_ids).to eq projects.map(&:id).map(&:to_s)
      end
    end
    ProjectRelatedTests::TESTS.each do |item|
      describe "when exporting #{item[:list]}" do
        before(:each) do
          exporter.public_send(item[:export_method])
        end
        it "creates one #{item[:klass].file_name} CSV file" do
          expect(File.exists?(csv_file_path(item[:klass]))).to be true
        end
        it "adds five rows to the #{item[:klass].file_name} CSV file" do
          csv = CSV.read(csv_file_path(item[:klass]), headers: true)
          expect(csv.count).to eq 5
        end
        it "hud keys in CSV should match source data" do
          csv = CSV.read(csv_file_path(item[:klass]), headers: true)
          current_hud_key = item[:klass].clean_headers([item[:klass].hud_key]).first.to_s
          csv_keys = csv.map{|m| m[current_hud_key]}
          source_keys = send(item[:list]).map(&:id).map(&:to_s)
          expect(csv_keys).to eq source_keys
        end
        if item[:klass].column_names.include?('ProjectID')
          it 'ProjectIDs from CSV file match project ids' do
            csv = CSV.read(csv_file_path(item[:klass]), headers: true)
            csv_project_ids = csv.map{|m| m['ProjectID']}
            source_ids = projects.map(&:id).map(&:to_s)
            expect(csv_project_ids).to eq source_ids
          end
        end
        
      end
    end
  end
  
  def csv_file_path klass
    File.join(exporter.file_path, klass.file_name)
  end

end