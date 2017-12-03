module Clients
  class AnomaliesController < ApplicationController
    before_action :require_can_track_anomalies!
    before_action :set_anomaly, only: [:edit, :update, :destroy]
    before_action :set_client
    
    def index
      @anomalies = @client.anomalies.group_by(&:status)
    end

    def edit

    end

    def update
      @anomaly.update(anomaly_params)
      respond_with(@anomaly, location: client_anomalies_path(@client))
    end

    def create
      @anomaly = @client.anomalies.build(anomaly_params.merge(
        status: :new, 
        submitted_by: current_user.id
      ))
      @anomaly.save
      respond_with(@anomaly, location: client_anomalies_path(@client))
    end

    def destroy
      
    end
    
    def set_anomaly
      @anomaly = anomaly_scope.find(params[:id].to_i)
    end

    def set_client
      @client = client_scope.find(params[:client_id].to_i)
    end

    def anomaly_scope
      GrdaWarehouse::Anomaly
    end

    def client_scope
      GrdaWarehouse::Hud::Client.destination
    end


    private def anomaly_params
      params.require(:anomaly).
        permit(
          :status,
          :description,
        )
    end
  end
end
