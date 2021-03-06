# From the Data Standards
# When a project reduces inventory, but will continue to serve the same household type with a smaller number of beds, a new record should be added with an 'Information Date’ of the effective date of the decrease; the same Inventory Start Date from the previous record should be used. The earlier record should be closed out by recording an Inventory End Date that is the day prior to the effective date of the decrease.
# 
# This is the clearest indication of how the three dates are supposed to function.
# 1. InventoryStartDate is when the physical beds/units were constructed
# 2. InformationDate is the start of when the beds can be used/counted
# 3. InventoryEndDate when the beds are no longer available for use
module GrdaWarehouse::Hud
  class Inventory < Base
    include HudSharedScopes
    self.table_name = 'Inventory'
    self.hud_key = :InventoryID
    acts_as_paranoid column: :DateDeleted
    include ArelHelper
    require 'csv'

    def self.hud_csv_headers(version: nil)
      [
        :InventoryID,
        :ProjectID,
        :CoCCode,
        :InformationDate,
        :HouseholdType,
        :Availability,
        :UnitInventory,
        :BedInventory,
        :CHBedInventory,
        :VetBedInventory,
        :YouthBedInventory,
        :BedType,
        :InventoryStartDate,
        :InventoryEndDate,
        :HMISParticipatingBeds,
        :DateCreated,
        :DateUpdated,
        :UserID,
        :DateDeleted,
        :ExportID,
      ].freeze
    end

    FAMILY_HOUSEHOLD_TYPE = 3
    INDIVIDUAL_HOUSEHOLD_TYPE = 1
    CHILD_ONLY_HOUSEHOLD_TYPE = 4

    belongs_to :export, **hud_belongs(Export), inverse_of: :inventories
    # has_one :project, through: :project_coc, source: :project
    has_one :project, **hud_belongs(Project), inverse_of: :inventories
    belongs_to :project_coc, class_name: 'GrdaWarehouse::Hud::ProjectCoc', primary_key: [:ProjectID, :CoCCode, :data_source_id], foreign_key: [:ProjectID, :CoCCode, :data_source_id], inverse_of: :inventories

    alias_attribute :start_date, :InventoryStartDate
    alias_attribute :end_date, :InventoryEndDate
    alias_attribute :beds, :BedInventory

    scope :within_range, -> (range) do
      where(
        i_t[:InformationDate].eq(nil).and(i_t[:InventoryStartDate].eq(nil)).and(i_t[:InventoryEndDate].eq(nil)).
        or(
          i_t[:InformationDate].lt(range.last).
          and(i_t[:InventoryEndDate].eq(nil))
        ).
        or(
          i_t[:InformationDate].lt(range.last).
          and(i_t[:InventoryEndDate].gt(range.first))
        ).
        or(
            i_t[:InformationDate].eq(nil).
            and(i_t[:InventoryStartDate].lt(range.last)).
            and(i_t[:InventoryEndDate].eq(nil))
        ).
        or(
            i_t[:InformationDate].eq(nil).
            and(i_t[:InventoryStartDate].lt(range.last)).
            and(i_t[:InventoryEndDate].gt(range.first))
        ).
        or(
            i_t[:InformationDate].eq(nil).
            and(i_t[:InventoryStartDate].eq(nil)).
            and(i_t[:InventoryEndDate].gt(range.first))
        )
      )
    end

    scope :serves_families, -> do
      where(HouseholdType: FAMILY_HOUSEHOLD_TYPE)
    end

    scope :family, -> do
      serves_families
    end

    scope :serves_individuals, -> do
      where(i_t[:HouseholdType].not_eq(FAMILY_HOUSEHOLD_TYPE).
          or(i_t[:HouseholdType].eq(nil)))
    end

    scope :individual, -> do
      serves_individuals
    end

    scope :serves_children, -> do
      where(HouseholdType: CHILD_ONLY_HOUSEHOLD_TYPE)
    end

    # when we export, we always need to replace InventoryID with the value of id
    # and ProjectID with the id of the related project
    def self.to_csv(scope:)
      attributes = self.hud_csv_headers.dup
      headers = attributes.clone
      attributes[attributes.index(:InventoryID)] = :id
      attributes[attributes.index(:ProjectID)] = 'project.id'

      CSV.generate(headers: true) do |csv|
        csv << headers

        scope.each do |i|
          csv << attributes.map do |attr|
            attr = attr.to_s
            # we need to grab the appropriate id from the related project
            if attr.include?('.')
              obj, meth = attr.split('.')
              i.send(obj).send(meth)
            # These items are numeric and should not be null, assume 0 if empty
            elsif ['HMISParticipatingBeds', 'BedInventory', 'UnitInventory'].include? attr
              i.send(attr).presence || 0
            else
              v = i.send(attr)
              if v.is_a? Date
                v = v.strftime("%Y-%m-%d")
              elsif v.is_a? Time
                v = v.to_formatted_s(:db)
              end
              v
            end
          end
        end
      end
    end

    def self.relevant_inventory(inventories:, date:)
      inventories = inventories.select{ |inv| inv.BedInventory.present? }
      if inventories.any?
        ref = date.to_time.to_i
        inventories.sort_by do |inv|
          ( ( inv.DateUpdated || inv.DateCreated ).to_time.to_i - ref ).abs
        end.first
      end
    end
  end
end