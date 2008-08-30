module RR

  # Provides helper functionality for the table syncers.
  # The methods exposed by this class are intended to provide a stable interface
  # for third party syncers.
  class SyncHelper

    # The current +TableSync+ instance
    attr_accessor :table_sync

    # The active +Session+
    def session; table_sync.session; end

    # Name of the left table
    def left_table; table_sync.left_table; end

    # Name of the right table
    def right_table; table_sync.right_table; end

    # Sync options for the current table sync
    def sync_options; table_sync.sync_options; end

    # Delegates to Committer#insert_record
    def insert_record(database, values)
      committer.insert_record(database, values)
    end

    # Delegates to Committer#insert_record
    def update_record(database, values)
      committer.update_record(database, values)
    end

    # Delegates to Committer#insert_record
    def delete_record(database, values)
      committer.delete_record(database, values)
    end

    def committer
      unless @committer
        committer_class = Committers::committers[sync_options[:committer]]
        @committer = committer_class.new(
          session, left_table, right_table, sync_options)
      end
      @committer
    end
    private :committer
    
    # Creates a new SyncHelper for the given +TableSync+ instance.
    def initialize(table_sync)
      self.table_sync = table_sync
    end
  end
end