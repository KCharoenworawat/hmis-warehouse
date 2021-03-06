FactoryGirl.define do
  factory :grda_warehouse_data_source, class: 'GrdaWarehouse::DataSource' do
    name 'Green River'
    short_name 'GR'
    # association :client, factory: :grda_warehouse_hud_client
    source_type nil
  end
  factory :data_source_fixed_id, class: 'GrdaWarehouse::DataSource' do
    id 1
    name 'Green River'
    short_name 'GR'
    # association :client, factory: :grda_warehouse_hud_client
    source_type :sftp
  end
  factory :source_data_source, class: 'GrdaWarehouse::DataSource' do
    name 'HMIS Vendor'
    short_name 'HV'
    # association :client, factory: :grda_warehouse_hud_client
    source_type :sftp
  end
end
