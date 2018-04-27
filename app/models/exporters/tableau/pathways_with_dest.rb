module Exporters::Tableau::PathwaysWithDest
  include ArelHelper
  include TableauExport
  
  module_function
    def to_csv(start_date: default_start, end_date: default_end, coc_code: nil)
      CSV.generate headers: true do |csv|
        pathways_common( start_date: start_date, end_date: end_date, coc_code: coc_code ).each do |row|
          csv << row
        end
      end
    end
  # End Module Functions
end