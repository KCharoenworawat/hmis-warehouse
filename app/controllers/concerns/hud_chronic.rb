module HudChronic
  extend ActiveSupport::Concern
  include ArelHelper
  # hc_t => GrdaWarehouse::HudChronic.arel_table

  included do
    def load_filter
      @filter = ::Filters::HudChronic.new(params[:filter])
      filter_query = hc_t[:age].gt(@filter.min_age)
      if @filter.individual
        filter_query = filter_query.and(hc_t[:individual].eq(@filter.individual))
      end
      if @filter.dmh
        filter_query = filter_query.and(hc_t[:dmh].eq(@filter.dmh))
      end
      if @filter.veteran
        filter_query = filter_query.and(c_t[:VeteranStatus].eq(@filter.veteran))
      end
      @clients = client_source.joins(:hud_chronics).
        preload(:hud_chronics).
        preload(:source_disabilities).
        where(filter_query).
        has_homeless_service_between_dates(start_date: (@filter.date - @filter.last_service_after.days), end_date: @filter.date)
      if @filter.name&.present?
        @clients = @clients.text_search(@filter.name, client_scope: GrdaWarehouse::Hud::Client.source)
      end
    end

    def set_sort
      client_at = client_source.arel_table
      @column = params[:sort] || 'months_in_last_three_years'
      @direction = if ['asc', 'desc'].include?(params[:direction])
        params[:direction]
      else
        'desc'
      end
      # whitelist for column
      table = if ['FirstName', 'LastName'].include?(@column) 
        client_at
      elsif chronic_source.column_names.include?(@column)
        hc_t
      else
        @column = 'months_in_last_three_years'
        hc_t
      end
      @order = table[@column].send(@direction)
    end

    def chronic_source
      GrdaWarehouse::HudChronic
    end

    def service_history_source
      GrdaWarehouse::ServiceHistory
    end
  end
end