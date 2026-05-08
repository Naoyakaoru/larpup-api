class ScriptVersionAddress < ApplicationRecord
  belongs_to :script_version
  belongs_to :address
end
