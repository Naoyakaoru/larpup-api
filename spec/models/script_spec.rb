require "rails_helper"

RSpec.describe Script, type: :model do
  describe "after_commit :ensure_base_version" do
    it "creates a base ScriptVersion (store_id nil) after create" do
      script = create(:script)
      expect(script.script_versions.where(store_id: nil).count).to eq(1)
    end

    it "does not create a duplicate when called again" do
      script = create(:script)
      expect { script.send(:ensure_base_version) }.not_to change(ScriptVersion, :count)
    end

    it "does not fire on update" do
      script = create(:script)
      initial_count = ScriptVersion.count
      script.update!(title: "#{script.title} updated")
      expect(ScriptVersion.count).to eq(initial_count)
    end

    it "does not create a new version when a soft-deleted base version exists" do
      script = create(:script)
      script.script_versions.find_by(store_id: nil).update_column(:deleted_at, Time.current)
      expect { script.send(:ensure_base_version) }.not_to change(ScriptVersion, :count)
    end
  end
end
