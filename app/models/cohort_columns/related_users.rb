module CohortColumns
  class RelatedUsers < Base
    attribute :column, String, lazy: true, default: :related_users
    attribute :title, String, lazy: true, default: 'Related Users'

    def default_input_type
      :read_only
    end

    def value(cohort_client)
      Rails.cache.fetch([cohort_client.client.id, :related_users], expires_at: 8.hours) do
        users = cohort_client.client.user_clients.
          non_confidential.
          active.
          pluck(:user_id, :relationship).to_h
        User.where(id: users.keys).map{|u| "#{users[u.id]} (#{u.name})"}.join('; ')
      end
    end
  end
end
