require_relative "sybase"
require_relative "discovery"
require "date"
require "yaml"

module Temps

  # kinda like mattr_accessor, but define @mssql too
  def self.set_opts=(opts_path)
    @opts = YAML.load_file(opts_path)[:temps]
  end

  #----------
  # A GeoGraphix crash can result in orphaned temporary tables. Project rebuilds
  # do not delete them, so we need to locate and remove them. Leaving them
  # can result in spurious odd behavior/crashes (mostly CrossSection).
  def self.check_temp_tables(proj, kill_temps)

    tmp_tables = Regexp.union [
      /^R_TEMP_SOURCE.*/i,
      /^WBFTT.*/i,
      /^GGX_TMP_CREATE_ZONES.*/i,
      /^TS_TEMP.*/i
    ]

    conn = Sybase.new(proj)

    puts "ggx_temps --> #{conn.project_server}/#{conn.project_home}/"\
    "#{conn.project_name}"

    gxdb = conn.db

    qualifier = "#{conn.project_name}-#{conn.project_home}".gsub(/\s/, "_")
    sql = "exec sp_tables '%', 'DBA', '#{qualifier}', \"'TABLE'\""

    gxdb[sql].all.select{ |t| t[:table_name].match(tmp_tables) }.map do |x|

      print x[:table_name]
      if kill_temps
        gxdb.drop_table x[:table_name].to_sym
        print "...and it's DELETED"
      end
      puts ""

    end
    gxdb.disconnect
  end


  #----------
  #
  def self.process_projects(kill_temps)
    begin

      @opts[:project_homes].each do |home|
        Discovery.project_list(home, @opts[:deep_scan]).each do |proj|
          check_temp_tables(proj, kill_temps)
        end
      end

    rescue Exception => e
      puts e.message
      puts e.backtrace
    end
  end

end

