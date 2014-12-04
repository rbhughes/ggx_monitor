#require_relative "sybase"
require_relative "mssql"
require_relative "discovery"
require "date"
require "yaml"

module Alerts

  @table_name = "z_ggx_alerts"

  @table_schema = Proc.new do
    primary_key :id
    String :project_server
    String :project_home
    String :project_name, :null => false
    String :alerts_summary, :text => true
    DateTime :row_created_date, :default => Sequel.function(:getdate)
  end

  #default and override options file
  #@opts = YAML.load_file("./settings.yml")[:alerts]

  # kinda like mattr_accessor
  def self.opts=(setpath)
    @opts = YAML.load_file(setpath)[:alerts]
    MSSQL.opts(setpath)
  end
  def self.opts
    @opts
  end

  #----------
  #
  def self.drop_table
    MSSQL.drop_table(@table_name)
  end

  #----------
  #
  def self.create_table
    MSSQL.create_table(@table_name, @table_schema)
  end

  #----------
  #
  def self.empty_table
    MSSQL.empty_table(@table_name)
  end


  #1. sybase table fragmentation 
  #alert if segs_per_row > 1.2
  #http://dcx.sybase.com/1100/en/dbusage_en11/ug-appprofiling-s-5641408.html
  def self.check_table_fragmentation(gxdb)
    #sql = "call sa_table_fragmentation();"
    sql = "exec sp_tables 'st%';"
    puts gxdb[sql].all
    #gxdb[sql].all.select{ |t| t[:segs_per_row] > 1.2 }.map do |x| 
    #  "Sybase Table Fragmentation: #{x[:tablename]}, (run rebuild)"
    #end
  end


  #2. gxdb.log too big
  #3. sybase log fragmentation
  #alert if gxdb.log exceeds an arbitrary number (400MBish)
  #alert if either gxdb.db or gxdb.log have fragmentation
  #(the multiplier adjusts to a human-readable scale)
  #http://dcx.sybase.com/1200/en/dbadmin/sa95c7b274-c1b8-42d4-bc08-4b66bc1c625a.html
  def self.check_file_frag_and_log_size(gxdb, proj)
    alerts = []
    db_size = File.size(File.join(proj, "gxdb.db"))
    log_size = File.size(File.join(proj, "gxdb.log"))

    fragged_threshold = 0.8
    scary = 400 * 1024**2 # 400MB converted to bytes
    alerts << "GXDB.log size > #{scary} MB. (run rebuild)" if log_size > scary

    sql = "select db_property('DBFileFragments') as db_frag, \
      db_property('LogFileFragments') as log_frag"

    gxdb[sql].all.each do |t|
      db_fragged = (t[:db_frag].to_f/db_size * 200000) > fragged_threshold
      log_fragged = (t[:log_frag].to_f/log_size * 200000) > fragged_threshold
      if (db_fragged || log_fragged)
        alerts << "Sybase File Fragmentation: gxdb.log & gxdb.db (run rebuild)"
      end
    end
    alerts
  end



  def self.check_valid_surface(gxdb)
    sql = "select list(uwi) as invalids from well where uwi in \
      (select top 20 uwi from well where \
      surface_longitude not between -180 and 180 or \
      surface_longitude = 0 or \
      surface_latitude not between -90 and 90 or \
      surface_latitude = 0 \
      order by uwi)"
    gxdb[sql].all.select{ |t| t[:invalids].size > 0 }.map do |x|
      "Invalid Surface Lat/Lon: #{x[:invalids]}. (non-null, zero or bad #)"
    end
  end

  def self.check_valid_bottom(gxdb)
    sql = "select list(uwi) as invalids from well where uwi in \
      (select top 20 uwi from well where \
      bottom_hole_longitude not between -180 and 180 or \
      bottom_hole_longitude = 0 or \
      bottom_hole_latitude not between -90 and 90 or \
      bottom_hole_latitude = 0 \
      order by uwi)"
    gxdb[sql].all.select{ |t| t[:invalids].size > 0 }.map do |x|
      "Invalid Bottom Hole Lat/Lon: #{x[:invalids]}. (non-null, zero or bad #)"
    end
  end



  def self.check_for_alerts(proj)
    alerts = []

    conn = Sybase.new(proj)

    h = {
      project_server: conn.project_server,
      project_home: conn.project_home,
      project_name: conn.project_name
    }

    gxdb = conn.db

    #puts check_file_frag_and_log_size(gxdb, proj).class
    puts check_table_fragmentation(gxdb).class
    #puts check_valid_surface(gxdb).class
    #puts check_valid_bottom(gxdb).class






    gxdb.disconnect



    #results.map do |h| 
    #  h[:project_server] = conn.project_server
    #  h[:project_home] = conn.project_home
    #  h[:project_name] = conn.project_name
    #end
    #results

  end

  #----------
  #
  def self.process_projects
    begin

      #MSSQL.empty_table(@table_name)

      project_alerts = []

      @opts[:project_homes].each do |home|
        #MSSQL.write_data(@table_name, logs)
        #puts home
        projects = Discovery.project_list(home, @opts[:deep_scan])

        projects.each do |proj|
          project_alerts.concat check_for_alerts(proj)
        end
      end
      puts project_alerts

    rescue Exception => e
      puts e.backtrace
    end
  end

end
