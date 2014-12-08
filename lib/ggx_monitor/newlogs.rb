require_relative "discovery"
require_relative "mssql"
require_relative "sybase"
require "date"
require "yaml"

module NewLogs

  @table_name = "z_ggx_newlogs"

  @table_schema = Proc.new do
    primary_key :id
    String :project_server
    String :project_home
    String :project_name, :null => false
    String :well_id, :null => false
    String :well_name
    String :operator
    String :state
    String :county
    String :curves
    DateTime :date_modified
    DateTime :row_created_date, :default => Sequel.function(:getdate)
  end

  # kinda like mattr_accessor, but define @mssql too
  def self.set_opts=(opts_path)
    @opts = YAML.load_file(opts_path)[:newlogs]
    @mssql = MSSQL.new(opts_path)
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
  # Query projects for any newly added digital log curves (presumably LAS)
  # that have been added (modified ~ imported) in the past N days.
  #
  def self.get_recent_logs(proj)
    conn = Sybase.new(proj)
    gxdb = conn.db

    sql = "select \
      c.wellid as well_id, \
      w.well_name, \
      w.operator, \
      w.province_state as state, \
      w.county, \
      list(c.curvename) as curves, \
      c.date_modified \ 
      from gx_well_curve c \
      join well w on c.wellid = w.uwi \
      where c.date_modified > getdate()-#{@opts[:days_ago]} \
      group by \
      c.wellid, \
      c.date_modified, \
      w.well_name, \
      w.operator, \
      w.province_state, \
      w.county"

    results = gxdb[sql].all

    results.map do |h| 
      h[:project_server] = conn.project_server
      h[:project_home] = conn.project_home
      h[:project_name] = conn.project_name
    end

    gxdb.disconnect
    results

  end

  #----------
  #
  def self.process_projects(days_ago)
    begin

      @mssql.empty_table(@table_name)
      @opts[:days_ago] = days_ago

      @opts[:projects].each do |proj|
        logs = get_recent_logs(proj)
        @mssql.write_data(@table_name, logs)
      end

    rescue Exception => e
      raise e
      #puts e.backtrace
    end
  end

  
end

