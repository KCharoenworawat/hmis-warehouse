# ### HIPPA Risk Assessment
# Risk: Relates to a patient and contains PHI
# Control: PHI attributes documented in base class
module Health
  class Goal::Clinical < Goal::Base
    def self.type_name
      'Clinical'
    end

  end
end