module GrdaWarehouse::Import::HMISSixOneOne
  class EmploymentEducation < GrdaWarehouse::Hud::EmploymentEducation
    include ::Import::HMISSixOneOne::Shared
    include TsqlImport
    self.hud_key = :EmploymentEducationID
    setup_hud_column_access( GrdaWarehouse::Hud::EmploymentEducation.hud_csv_headers(version: '6.11') )

    def self.date_provided_column
      :InformationDate
    end

    def self.file_name
      'EmploymentEducation.csv'
    end

  end
end