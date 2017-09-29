# these are also sometimes called programs
module GrdaWarehouse::Hud
  class Project < Base
    include ArelHelper
    self.table_name = :Project
    self.hud_key = :ProjectID
    acts_as_paranoid column: :DateDeleted

    def self.hud_csv_headers(version: nil)
      [
        "ProjectID",
        "OrganizationID",
        "ProjectName",
        "ProjectCommonName",
        "ContinuumProject",
        "ProjectType",
        "ResidentialAffiliation",
        "TrackingMethod",
        "TargetPopulation",
        "PITCount",
        "DateCreated",
        "DateUpdated",
        "UserID",
        "DateDeleted",
        "ExportID"
      ]
    end

   include Filterable

    RESIDENTIAL_PROJECT_TYPES = {}.tap do |pt|
      h = {   # duplicate of code in various places
        ph: [3,9,10,13],
        th: [2],
        es: [1],
        so: [4],
        sh: [8],
      }
      pt.merge! h
      pt[:permanent_housing]    = h[:ph]
      pt[:transitional_housing] = h[:th]
      pt[:emergency_shelter]    = h[:es]
      pt[:street_outreach]      = h[:so]
      pt[:safe_haven]           = h[:sh]
      pt.freeze
    end

    RESIDENTIAL_PROJECT_TYPE_IDS = RESIDENTIAL_PROJECT_TYPES.values.flatten.uniq.sort

    CHRONIC_PROJECT_TYPES = RESIDENTIAL_PROJECT_TYPES.values_at(:es, :so, :sh).flatten
    HOMELESS_PROJECT_TYPES = RESIDENTIAL_PROJECT_TYPES.values_at(:es, :so, :sh, :th).flatten
    PROJECT_TYPE_TITLES = {
        ph: 'Permanent Housing',
        es: 'Emergency Shelter',
        th: 'Transitional Housing',
        sh: 'Safe Haven',
        so: 'Street Outreach',
      }
    HOMELESS_TYPE_TITLES = PROJECT_TYPE_TITLES.except(:ph)
    CHRONIC_TYPE_TITLES = PROJECT_TYPE_TITLES.except(:ph)
    PROJECT_TYPE_COLORS = {
      ph: 'rgba(150, 3, 130, 0.5)',
      th: 'rgba(103, 81, 140, 0.5)',
      es: 'rgba(87, 132, 93, 0.5)',
      so: 'rgba(132, 26, 7, 0.5)',
      sh: 'rgba(61, 99, 130, 0.5)',
    }

    attr_accessor :hud_coc_code
    belongs_to :organization, class_name: 'GrdaWarehouse::Hud::Organization', primary_key: ['OrganizationID', :data_source_id], foreign_key: ['OrganizationID', :data_source_id], inverse_of: :projects
    belongs_to :data_source, inverse_of: :projects
    belongs_to :export, **hud_belongs(Export), inverse_of: :projects

    has_and_belongs_to_many :project_groups, 
      class_name: GrdaWarehouse::ProjectGroup.name,
      join_table: :project_project_groups

    has_many :service_history, class_name: 'GrdaWarehouse::ServiceHistory', primary_key: [:data_source_id, :ProjectID, :OrganizationID], foreign_key: [:data_source_id, :project_id, :organization_id]
    has_many :project_cocs, **hud_many(ProjectCoc), inverse_of: :project
    has_many :sites, through: :project_cocs, source: :sites
    has_many :enrollments, class_name: 'GrdaWarehouse::Hud::Enrollment', primary_key: ['ProjectID', :data_source_id], foreign_key: ['ProjectID', :data_source_id], inverse_of: :project
    has_many :income_benefits, through: :enrollments, source: :income_benefits
    has_many :disabilities, through: :enrollments, source: :disabilities
    has_many :employment_educations, through: :enrollments, source: :employment_educations
    has_many :health_and_dvs, through: :enrollments, source: :health_and_dvs
    has_many :services, through: :enrollments, source: :services
    has_many :exits, through: :enrollments, source: :exit
    has_many :inventories, through: :project_cocs, source: :inventories
    has_many :clients, through: :enrollments, source: :client
    has_many :funders, class_name: 'GrdaWarehouse::Hud::Funder', primary_key: ['ProjectID', :data_source_id], foreign_key: ['ProjectID', :data_source_id], inverse_of: :projects
    has_many :affiliations, **hud_many(Affiliation), inverse_of: :project
    has_many :enrollment_cocs, **hud_many(EnrollmentCoc), inverse_of: :project
    has_many :funders, **hud_many(Funder), inverse_of: :project
    has_many :user_viewable_entities, as: :entity, class_name: 'GrdaWarehouse::UserViewableEntity'

    # Warehouse Reporting
    has_many :data_quality_reports, class_name: GrdaWarehouse::WarehouseReports::Project::DataQuality::Base.name
    has_one :current_data_quality_report, -> do
      where(processing_errors: nil).where.not(completed_at: nil).order(created_at: :desc).limit(1)
    end, class_name: GrdaWarehouse::WarehouseReports::Project::DataQuality::Base.name
    has_many :contacts, class_name: GrdaWarehouse::Contact::Project.name, foreign_key: :entity_id
    has_many :organization_contacts, through: :organization, source: :contacts

    scope :residential, -> do
      where(ProjectType: RESIDENTIAL_PROJECT_TYPE_IDS)
    end
    scope :hud_residential, -> do
      where(self.project_type_override.in(RESIDENTIAL_PROJECT_TYPE_IDS))
    end
    scope :non_residential, -> do 
      where.not(ProjectType: RESIDENTIAL_PROJECT_TYPE_IDS)
    end
    scope :hud_non_residential, -> do
      where.not(self.project_type_override.in(RESIDENTIAL_PROJECT_TYPE_IDS))
    end

    scope :chronic, -> do
      where(ProjectType: CHRONIC_PROJECT_TYPES)
    end
    scope :hud_chronic, -> do
      where(self.project_type_override.in(CHRONIC_PROJECT_TYPES))
    end
    scope :homeless, -> do
      where(ProjectType: HOMELESS_PROJECT_TYPES)
    end
    scope :hud_homeless, -> do
      where(self.project_type_override.in(HOMELESS_PROJECT_TYPES))
    end
    scope :residential_non_homeless, -> do
      r_non_homeless = GrdaWarehouse::Hud::Project::RESIDENTIAL_PROJECT_TYPE_IDS - GrdaWarehouse::Hud::Project::CHRONIC_PROJECT_TYPES
      where(ProjectType: r_non_homeless)
    end
    scope :hud_residential_non_homeless, -> do
      r_non_homeless = GrdaWarehouse::Hud::Project::RESIDENTIAL_PROJECT_TYPE_IDS - GrdaWarehouse::Hud::Project::CHRONIC_PROJECT_TYPES
      where(self.project_type_override.in(r_non_homeless))
    end

    scope :coc_funded, -> do
      # hud_continuum_funded overrides ContinuumProject
      where(
        arel_table[:ContinuumProject].eq(1).and(arel_table[:hud_continuum_funded].eq(nil)).
        or(arel_table[:hud_continuum_funded].eq(true))
      )
    end

    # NOTE: Careful, this returns duplicates as it joins inventories.
    # You may want to tack on a distinct, depending on what you need. 
    scope :serves_families, -> do
      joins(:inventories).merge(GrdaWarehouse::Hud::Inventory.serves_families)
    end
    def serves_families?
      self.class.serves_families.where(id: id).exists?
    end

    # NOTE: Careful, this returns duplicates as it joins inventories.
    # You may want to tack on a distinct, depending on what you need.
    scope :serves_individuals, -> do
      joins(:inventories).merge(GrdaWarehouse::Hud::Inventory.serves_individuals)
    end
    def serves_individuals?
      self.class.serves_individuals.where(id: id).exists?
    end

    # NOTE: Careful, this returns duplicates as it joins inventories.
    # You may want to tack on a distinct, depending on what you need.
    scope :serves_individuals_only, -> do
      joins(:inventories).merge(GrdaWarehouse::Hud::Inventory.serves_individuals).
      where.not(Inventory: {id: GrdaWarehouse::Hud::Inventory.serves_families})
    end
    def serves_only_individuals?
      self.class.serves_individuals_only.where(id: id).exists?
    end

    scope :viewable_by, -> (user) do
      if user.can_edit_anything_super_user?
        current_scope
      else
        qc = -> (s) { connection.quote_column_name s }
        q  = -> (s) { connection.quote s }

        where(
          [
            has_access_to_project_through_viewable_entities(user, q, qc),
            has_access_to_project_through_organization(user, q, qc),
            has_access_to_project_through_data_source(user, q, qc)
          ].join ' OR '
        )
      end
    end
    scope :editable_by, -> (user) { viewable_by user }

    private_class_method def self.has_access_to_project_through_viewable_entities(user, q, qc)
      viewability_table = GrdaWarehouse::UserViewableEntity.quoted_table_name
      project_table     = quoted_table_name

      <<-SQL.squish

        EXISTS (
          SELECT 1 FROM
            #{viewability_table}
            WHERE
              #{viewability_table}.#{qc.('entity_id')}   = #{project_table}.#{qc.('id')}
              AND
              #{viewability_table}.#{qc.('entity_type')} = #{q.(sti_name)}
              AND
              #{viewability_table}.#{qc.('user_id')}     = #{user.id}
        )

      SQL
    end

    private_class_method def self.has_access_to_project_through_organization(user, q, qc)
      viewability_table   = GrdaWarehouse::UserViewableEntity.quoted_table_name
      project_table       = quoted_table_name
      organization_table  = GrdaWarehouse::Hud::Organization.quoted_table_name

      <<-SQL.squish

        EXISTS (
          SELECT 1 FROM
            #{viewability_table}
            INNER JOIN
            #{organization_table}
            ON
              #{viewability_table}.#{qc.('entity_id')}   = #{organization_table}.#{qc.('id')}
              AND
              #{viewability_table}.#{qc.('entity_type')} = #{q.(GrdaWarehouse::Hud::Organization.sti_name)}
              AND
              #{viewability_table}.#{qc.('user_id')}     = #{user.id}
            WHERE
              #{organization_table}.#{qc.('data_source_id')} = #{project_table}.#{qc.('data_source_id')}
              AND
              #{organization_table}.#{qc.('OrganizationID')} = #{project_table}.#{qc.('OrganizationID')}
              AND
              #{organization_table}.#{qc.(GrdaWarehouse::Hud::Organization.paranoia_column)} IS NULL
        )

      SQL
    end

    private_class_method def self.has_access_to_project_through_data_source(user, q, qc)
      data_source_table = GrdaWarehouse::DataSource.quoted_table_name
      viewability_table = GrdaWarehouse::UserViewableEntity.quoted_table_name
      project_table     = quoted_table_name

      <<-SQL.squish

        EXISTS (
          SELECT 1 FROM
            #{viewability_table}
            INNER JOIN
            #{data_source_table}
            ON
              #{viewability_table}.#{qc.('entity_id')}   = #{data_source_table}.#{qc.('id')}
              AND
              #{viewability_table}.#{qc.('entity_type')} = #{q.(GrdaWarehouse::DataSource.sti_name)}
              AND
              #{viewability_table}.#{qc.('user_id')}     = #{user.id}
            WHERE
              #{project_table}.#{qc.('data_source_id')} = #{data_source_table}.#{qc.('id')}
        )

      SQL
    end

    # make a scope for every project type and a type? method for instances
    RESIDENTIAL_PROJECT_TYPES.each do |k,v|
      scope k, -> { where ProjectType: v }
      define_method "#{k}?" do
        v.include? self.ProjectType
      end
    end

    alias_attribute :name, :ProjectName

    def self.project_type_override
      p_t[:computed_project_type]
      # cl(p_t[:act_as_project_type], p_t[:ProjectType])
    end

    def compute_project_type
      act_as_project_type.presence || self.ProjectType
    end

    def organization_and_name(include_confidential_names: false)
      if include_confidential_names
        "#{organization&.name} / #{name}"
      else
        project_name = self.class.confidentialize(name: name)
        if project_name == self.class.confidential_project_name
          "#{project_name}"
        else
          "#{organization&.name} / #{name}"
        end
      end
    end

    def bed_night_tracking?
      self.TrackingMethod == 3 || street_outreach_and_acts_as_bednight?
    end

    # Some Street outreach are counted like bed-night shelters, others aren't yet
    def street_outreach_and_acts_as_bednight?
      return false unless so?
      @answer ||= GrdaWarehouse::Hud::Project.where(id: id)
        .joins(:services)
        .select(:ProjectID, :data_source_id)
        .where(Services: {RecordType: 12})
        .exists?
      @answer
    end

    # when we export, we always need to replace ProjectID with the value of id
    # and OrganizationID with the id of the related organization
    def self.to_csv(scope:, override_project_type:)
      attributes = self.hud_csv_headers
      headers = attributes.clone
      attributes[attributes.index('ProjectID')] = 'id'
      attributes[attributes.index('OrganizationID')] = 'organization.id'

      CSV.generate(headers: true) do |csv|
        csv << headers

        scope.each do |i|
          csv << attributes.map do |attr|
            # we need to grab the appropriate id from the related organization
            if attr.include?('.')
              obj, meth = attr.split('.')
              i.send(obj).send(meth)
            else
              if override_project_type && attr == 'ProjectType'
                i.computed_project_type
              elsif attr == 'ResidentialAffiliation'
                i.send(attr).presence || 99
              elsif attr == 'TrackingMethod'
                i.send(attr).presence || 0
              else
                i.send(attr)
              end
            end 
          end
        end
      end
    end

    def safe_project_name
      if confidential?
        self.class.confidential_project_name
      else
        self.ProjectName
      end
    end

    # Sometimes all we have is a name, we still want to try and 
    # protect those
    def self.confidentialize(name:)
      @confidential_project_names ||= GrdaWarehouse::Hud::Project.where(confidential: true).
        pluck(:ProjectName).
        map(&:downcase).
        map(&:strip)
      if @confidential_project_names.include?(name&.downcase&.strip) || /healthcare/i.match(name).present?
        GrdaWarehouse::Hud::Project.confidential_project_name
      else
        name
      end
    end

    def self.confidential_project_name
      'Confidential Project'
    end

    def self.project_type_column
      if GrdaWarehouse::Config.get(:project_type_override)
        :computed_project_type
      else
        :ProjectType
      end
    end

    private def organization_source
      GrdaWarehouse::Hud::Organization
    end

    def self.text_search(text)
      return none unless text.present?

      query = "%#{text}%"

      org_matches = GrdaWarehouse::Hud::Organization.where(
        GrdaWarehouse::Hud::Organization.arel_table[:OrganizationID].eq(arel_table[:OrganizationID])
        .and(GrdaWarehouse::Hud::Organization.arel_table[:data_source_id].eq(arel_table[:data_source_id]))
      ).text_search(text).exists

      where(
        arel_table[:ProjectName].matches(query)
        .or(org_matches)
      )
    end
  end
end