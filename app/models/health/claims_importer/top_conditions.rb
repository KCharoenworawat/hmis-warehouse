module Health::ClaimsImporter
  class TopConditions < Base
    self.table_name = :claims_top_conditions

    def column_headers 
      {
        medicaid_id: "ID_Medicaid",
        rank: "Rank",
        description: "Description",
        indiv_pct: "Indiv_pct",
        sdh_pct: "SDH_pct",
      }
    end

  end
end