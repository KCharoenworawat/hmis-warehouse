module WarehouseReports
  class AnomaliesController < ApplicationController
    include WarehouseReportAuthorization
    include ArelHelper

    def index
      @new = anomaly_scope.newly_minted.order(created_at: :asc).preload(:client, :user)
      @unresolved = anomaly_scope.unresolved.order(created_at: :asc).preload(:client, :user)
      @resolved = anomaly_scope.resolved.order(created_at: :asc).preload(:client, :user)
    end

    def anomaly_source
      GrdaWarehouse::Anomaly
    end

    def anomaly_scope
      if can_edit_anything_super_user?
        anomaly_source
      else
        anomaly_source.where(submitted_by: current_user.id)
      end
    end
  end
end
