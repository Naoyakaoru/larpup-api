class AddStatusTimestampsToEventMembers < ActiveRecord::Migration[7.2]
  def change
    add_column :event_members, :rejected_at, :datetime
    add_column :event_members, :leave_requested_at, :datetime
    add_column :event_members, :cancelled_at, :datetime
  end
end
