module GrdaWarehouse::Export::HMISSixOneOne
  class Affiliation < GrdaWarehouse::Import::HMISSixOneOne::Affiliation
    include ::Export::HMISSixOneOne::Shared
    setup_hud_column_access( 
      [
        :AffiliationID,
        :ProjectID,
        :ResProjectID,
        :DateCreated,
        :DateUpdated,
        :UserID,
        :DateDeleted,
        :ExportID,
      ]
    )
    
    self.hud_key = :AffiliationID

    belongs_to :project_with_deleted, class_name: GrdaWarehouse::Hud::WithDeleted::Project.name, primary_key: [:ProjectID, :data_source_id], foreign_key: [:ProjectID, :data_source_id], inverse_of: :affiliations

    def self.export! project_scope:, path:, export:
      if export.include_deleted
        affiliation_scope = joins(:project_with_deleted).merge(project_scope)
      else
        affiliation_scope = joins(:project).merge(project_scope)
      end
      export_to_path(export_scope: affiliation_scope, path: path, export: export)
    end

  end
end