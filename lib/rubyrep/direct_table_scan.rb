module RR

  # Scans two tables for differences.
  # Doesn't have any reporting functionality by itself. 
  # Instead DirectTableScan#run yields all the differences for the caller to do with as it pleases.
  # Usage:
  #   1. Create a new DirectTableScan object and hand it all necessary information
  #   2. Call DirectTableScan#run to do the actual comparison
  #   3. The block handed to DirectTableScan#run receives all differences
  class DirectTableScan < TableScan
    include TableScanHelper

    # The TypeCastingCursor for the left table
    attr_accessor :left_caster
    
    # The TypeCastingCursor for the right table
    attr_accessor :right_caster

    # Creates a new DirectTableScan instance
    #   * session: a Session object representing the current database session
    #   * left_table: name of the table in the left database
    #   * right_table: name of the table in the right database. If not given, same like left_table
    def initialize(session, left_table, right_table = nil)
      super
    end
    
    # Runs the table scan.
    # Calls the block for every found difference.
    # Differences are yielded with 2 parameters
    #   * type: describes the difference, either :left (row only in left table), :right (row only in right table) or :conflict
    #   * row: for :left or :right cases a hash describing the row; for :conflict an array of left and right row
    def run(&blck)
      left_cursor = right_cursor = nil
      left_cursor = TypeCastingCursor.new(session.left, left_table, session.left.select_cursor(construct_query(left_table)))
      right_cursor = TypeCastingCursor.new(session.right, right_table, session.right.select_cursor(construct_query(right_table))) 
      left_row = right_row = nil
      while left_row or right_row or left_cursor.next? or right_cursor.next?
        # if there is no current left row, _try_ to load the next one
        left_row ||= left_cursor.next_row if left_cursor.next?
        # if there is no current right row, _try_ to load the next one
        right_row ||= right_cursor.next_row if right_cursor.next?
        rank = rank_rows left_row, right_row
        case rank
        when -1
          yield :left, left_row
          left_row = nil
        when 1
          yield :right, right_row
          right_row = nil
        when 0
          if not left_row == right_row
            yield :conflict, [left_row, right_row]
          end
          left_row = right_row = nil
        end
        # check for corresponding right rows
      end
    ensure
      [left_cursor, right_cursor].each {|cursor| cursor.clear if cursor}
    end
    
    # Generates the SQL query to iterate through the given target table.
    # Note: The column & order part of the query are always generated based on left_table.
    def construct_query(target_table)
      column_names = session.left.columns(left_table).map {|column| column.name}
      "select #{column_names.join(', ')} from #{target_table} order by #{primary_key_names.join(', ')}"
    end
  end
end