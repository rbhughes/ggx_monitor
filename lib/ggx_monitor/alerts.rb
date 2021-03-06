require_relative "discovery"
require_relative "mssql"
require_relative "sybase"
require "date"

module Alerts

  @table_name = "ggx_alerts"
  @proj = nil
  @gxdb = nil

  @table_schema = Proc.new do
    primary_key :id
    String :project_server
    String :project_home
    String :project_name, :null => false
    String :alerts_summary, :text => true
    DateTime :row_created_date, :default => Sequel.function(:getdate)
  end

  # kinda like mattr_accessor, but define @mssql too
  def self.set_opts=(options)
    @opts = options
    @mssql = MSSQL.new(options)
  end

  #----------
  #
  def self.drop_table
    @mssql.drop_table(@table_name)
  end

  #----------
  #
  def self.create_table
    @mssql.create_table(@table_name, @table_schema)
  end

  #----------
  def self.empty_table
    @mssql.empty_table(@table_name)
  end

  #----------
  def self.read_table
    @mssql.read_data(@table_name)
  end


  #----------
  # * sybase table fragmentation 
  # alert if segs_per_row > 1.2
  # http://dcx.sybase.com/1100/en/dbusage_en11/ug-appprofiling-s-5641408.html
  def self.check_table_fragmentation
    fragged_threshold = 1.2
    sql = "call sa_table_fragmentation();"
    @gxdb[sql].all.select{ |t| t[:segs_per_row] > fragged_threshold }.map do |x| 
      "Sybase Table Fragmentation: #{x[:tablename]}, (run rebuild)"
    end
  end

  #----------
  # * gxdb.log too big
  # * sybase log fragmentation
  # alert if gxdb.log exceeds an arbitrary number (400MBish)
  # alert if either gxdb.db or gxdb.log have fragmentation
  # (the multiplier adjusts to a human-readable scale)
  # http://dcx.sybase.com/1200/en/dbadmin/sa95c7b274-c1b8-42d4-bc08-4b66bc1c625a.html
  def self.check_file_frag_and_log_size
    alerts = []
    db_size = File.size(File.join(@proj, "gxdb.db"))
    log_size = File.size(File.join(@proj, "gxdb.log"))

    fragged_threshold = 1.1
    scary = 400 * 1024**2 # 400MB converted to bytes
    alerts << "GXDB.log size > #{scary} MB. (run rebuild)" if log_size > scary

    sql = "select db_property('DBFileFragments') as db_frag, \
      db_property('LogFileFragments') as log_frag"

    @gxdb[sql].all.each do |t|
      db_fragged = (t[:db_frag].to_f/db_size * 200000) > fragged_threshold
      log_fragged = (t[:log_frag].to_f/log_size * 200000) > fragged_threshold
      if (db_fragged || log_fragged)
        alerts << "Sybase File Fragmentation: gxdb.log & gxdb.db (run rebuild)"
      end
    end
    alerts
  end

  #----------
  # * invalid surface lat/lon
  # alert if lat/lons are not in normal range or are zero (null is okay)
  def self.check_valid_surface
    sql = "select list(uwi) as invalids from well where uwi in \
      (select top 20 uwi from well where \
      surface_longitude not between -180 and 180 or \
      surface_longitude = 0 or \
      surface_latitude not between -90 and 90 or \
      surface_latitude = 0 \
      order by uwi)"
    @gxdb[sql].all.select{ |t| t[:invalids].size > 0 }.map do |x|
      "Invalid Surface Lat/Lon: #{x[:invalids]}. ('0' or not lat/lon range)"
    end
  end

  #----------
  # * invalid bottom hole lat/lon
  # alert if lat/lons are not in normal range or are zero (null is okay)
  def self.check_valid_bottom
    sql = "select list(uwi) as invalids from well where uwi in \
      (select top 20 uwi from well where \
      bottom_hole_longitude not between -180 and 180 or \
      bottom_hole_longitude = 0 or \
      bottom_hole_latitude not between -90 and 90 or \
      bottom_hole_latitude = 0 \
      order by uwi)"
    @gxdb[sql].all.select{ |t| t[:invalids].size > 0 }.map do |x|
      "Invalid Bottom Hole Lat/Lon: #{x[:invalids]}. ('0' or not lat/lon range)"
    end
  end

  #----------
  # Failed rebuilds leave these files behind and block subsequent rebuilds
  def self.check_rebuild_leftovers
    [
      File.join(@proj, "gxdb.dbR"),
      File.join(@proj, "gxdb_production.dbR"),
      File.join(@proj, "gxdb.logR")
    ].map do |f|
      "Leftover from rebuild: #{f}" if File.exists?(f)
    end.compact
  end

  #----------
  #
  def self.collect_alerts

    project_server = Discovery.parse_host(@proj)
    project_home = Discovery.parse_home(@proj)
    project_name = File.basename(@proj)

    print "ggx_alerts --> #{project_server}/#{project_home}/#{project_name}"

    alerts = []
    @gxdb = Sybase.new(@proj).db

    alert = {
      project_server: project_server,
      project_home: project_home,
      project_name: project_name
    }

    #alerts.concat check_table_fragmentation #SKIP, IT'S TOO SLOW
    #print "."

    alerts.concat check_file_frag_and_log_size
    print "."
    alerts.concat check_valid_surface
    print "."
    alerts.concat check_valid_bottom
    print "."
    alerts.concat check_rebuild_leftovers
    print "."

    alert[:alerts_summary] = alerts.join("\n")

    @gxdb.disconnect
    puts
    return alert
  end


  #----------
  #
  def self.process_projects
    begin

      @mssql.empty_table(@table_name)

      all_projects = []

      @opts[:project_homes].each do |home|
        Discovery.project_list(home, @opts[:deep_scan]).each do |proj|
          @proj = proj
          all_projects << collect_alerts
        end
      end

      alertable_projects = all_projects.reject{ |x| x[:alerts_summary].empty? }
      @mssql.write_data(@table_name, alertable_projects)

    rescue Exception => e
      raise e
    end
  end

end
