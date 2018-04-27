module Exporters::Tableau::Disability
  include ArelHelper
  include TableauExport
  
  module_function
  def to_csv(start_date: default_start, end_date: default_end, coc_code: nil)
      spec = {
        entry_exit_uid:       e_t[:ProjectEntryID],
        entry_exit_client_id: she_t[:client_id],
        disability_type:      d_t[:DisabilityType],
        start_date:           she_t[:first_date_in_program],
        end_date:             she_t[:last_date_in_program],
      }

      model = c_t.engine

      scope = model.
        joins( service_history_enrollments: { enrollment: [ :disabilities, :enrollment_coc_at_entry ] } ).
        merge( she_t.engine.open_between start_date: start_date, end_date: end_date ).
        where( d_t[:DisabilityResponse].in [1,2,3] ).
        # for aesthetics
        order( she_t[:client_id].asc ).
        order( she_t[:first_date_in_program].desc ).
        order( she_t[:last_date_in_program].desc ).
        # for de-duping
        order( d_t[:InformationDate].desc )

      if coc_code.present?
        scope = scope.where( ec_t[:CoCCode].eq coc_code )
      end
      clients = scope

      spec.each do |header, selector|
        clients = clients.select selector.as(header.to_s)
      end

      CSV.generate headers: true do |csv|
        headers = spec.keys
        csv << headers

        clients = model.connection.select_all(clients.to_sql).group_by do |h|
          h.values_at %w( entry_exit_uid entry_exit_client_id start_date end_date )
        end
        # after sorting and grouping, we keep only the most recent disability record
        clients.each do |_,(client,*)|
          row = []
          headers.each do |h|
            value = client[h.to_s].presence
            value = case h
            when :disability_type
              ::HUD.disability_type(value&.to_i)&.titleize
            when :start_date, :end_date
              value && DateTime.parse(value).strftime('%Y-%m-%d')
            else
              value
            end
            row << value
          end
          csv << row
        end
       end
    end

    def income(start_date: default_start, end_date: default_end, coc_code:)
      model = ib_t.engine

      spec = {
        grouping_variable:       she_t[:id],
        entry_exit_uid:          e_t[:ProjectEntryID],
        entry_exit_client_id:    she_t[:client_id],
        earned_income:           ib_t[:Earned],
        ssi_ssdi:                ib_t[:SSI],
        tanf:                    ib_t[:TANF],
        source_of_income:        ib_t[:SSDI],
        receiving_income_source: ib_t[:IncomeFromAnySource],
        start_date:              she_t[:first_date_in_program],
        end_date:                she_t[:last_date_in_program],
      }

      incomes = model.
        joins( enrollment: [ :enrollment_coc_at_entry, :service_history_enrollment ] ).
        merge( she_t.engine.open_between start_date: start_date, end_date: end_date ).
        where( ec_t[:CoCCode].eq coc_code ).
        # for aesthetics
        order(she_t[:client_id].asc).
        order(she_t[:first_date_in_program].desc).
        order(she_t[:last_date_in_program].desc).
        # for de-duping
        order(ib_t[:InformationDate].desc)
      spec.each do |header, selector|
        incomes = incomes.select selector.as(header.to_s)
      end

      csv = CSV.generate headers: true do |csv|
        headers = spec.keys - [:grouping_variable]
        csv << headers

        incomes = model.connection.select_all(incomes.to_sql)
        # get the *most recent* ib per enrollment and ignore the rest
        incomes.group_by{ |h| h['grouping_variable'] }.each do |_,(income,*)|
          row = []
          ssi, ssdi, tanf, earned_income = %w( ssi_ssdi source_of_income tanf earned_income ).map{ |f| income[f].presence&.to_i == 1 }
          headers.each do |h|
            value = income[h.to_s].presence
            value = case h
            when :start_date, :end_date
              value && DateTime.parse(value).strftime('%Y-%m-%d')
            when :earned_income
              earned_income ? 'Yes' : 'No'
            when :tanf
              tanf ? 'Yes' : 'No'
            when :ssi_ssdi
              if ssi || ssdi
                'Yes'
              else
                'No'
              end
            when :source_of_income
              # pure guessword
              source = if earned_income
                'Earned Income'
              elsif ssi
                'SSI'
              elsif ssdi
                'SSDI'
              elsif tanf
                'TANF'
              end
              "#{source} (HUD)" if source
            when :receiving_income_source
              value&.to_i == 1 ? 'Yes' : 'No'
            else
              value
            end
            row << value
          end
          csv << row
        end
       end
    end
  # End Module Functions
end