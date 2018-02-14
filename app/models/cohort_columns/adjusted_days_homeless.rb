module CohortColumns
  class AdjustedDaysHomeless < Base
    attribute :column, String, lazy: true, default: :adjusted_days_homeless
    attribute :title, String, lazy: true, default: 'Static Days Homeless'

    def default_input_type
      :integer
    end

    def has_default_value?
      true
    end

    def default_value client_id
      GrdaWarehouse::Hud::Client.days_homeless(client_id: client_id)
    end

  end
end