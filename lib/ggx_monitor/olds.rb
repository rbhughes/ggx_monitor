require_relative "discovery"
require_relative "sybase"
require "date"

module Olds

  @proj = nil

  # kinda like mattr_accessor, but define @mssql too
  def self.set_opts=(options)
    @opts = options
  end



  #----------
  # Query projects for any newly added digital log curves (presumably LAS)
  # that have been added (modified ~ imported) in the past N days.
  #
  def self.collect_newlogs

    project_server = Discovery.parse_host(@proj)
    project_home = Discovery.parse_home(@proj)
    project_name = File.basename(@proj)

    print "ggx_newlogs --> #{project_server}/#{project_home}/#{project_name}"

    gxdb = Sybase.new(@proj).db

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
      h[:project_server] = project_server
      h[:project_home] = project_home
      h[:project_name] = project_name
    end

    gxdb.disconnect
    puts
    results
  end

  #----------
  #
  def self.process_projects
    begin


      @opts[:project_homes].each do |home|
        Discovery.project_list(home, @opts[:deep_scan]).each do |proj|
          @proj = proj
          puts @proj

        end
      end

      #@opts[:days_ago] = days_ago


    rescue Exception => e
      raise e
    end
  end

  
end


