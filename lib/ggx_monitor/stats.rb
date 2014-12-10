require_relative "discovery"
require_relative "mssql"
require_relative "sybase"
require "nokogiri"
require "date"
require "yaml"

module Stats
  @table_name = "z_ggx_stats"
  @proj = nil
  @gxdb = nil

  @table_schema = Proc.new do
    primary_key :id
    String :project_server
    String :project_home
    String :project_name, :null => false
    String :schema_version
    Fixnum :activity_score
    String :full_path
    Bignum :file_count
    Bignum :byte_size
    String :human_size
    DateTime :proj_oldest_mod
    DateTime :proj_newest_mod
    String :surface_bounds
    String :interpreters, :text => true
    String :coordinate_system
    Fixnum :avg_file_age
    Bignum :num_wells
    Bignum :num_digital_curves
    Bignum :num_raster_curves
    Bignum :num_formations
    Bignum :num_zone_attr
    Bignum :num_layers_maps
    Bignum :num_dir_surveys
    Bignum :num_sv_interps
    Fixnum :age_wells
    Fixnum :age_digital_curves
    Fixnum :age_raster_curves
    Fixnum :age_formations
    Fixnum :age_zone_attr
    Fixnum :age_layers_maps
    Fixnum :age_dir_surveys
    Fixnum :age_sv_interps
    DateTime :row_created_date, :default => Sequel.function(:getdate)
  end

  # kinda like mattr_accessor, but define @mssql too
  def self.set_opts=(opts_path)
    @opts = YAML.load_file(opts_path)[:stats]
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
  #----------


  #----------
  #
  def self.interpreters
    uf = File.join(@proj, "User Files")
    return unless File.exists?(uf)
    Dir.glob(File.join(uf,"*")).map{ |f| File.basename(f) }.join(", ")
  end

  def self.version_and_coordsys
    pxml = File.join(@proj, "Project.ggx.xml")
    pggx = File.join(@proj, "Project.ggx")

    if File.exists?(pxml)
      doc = Nokogiri::XML(pxml)
    end
    puts doc


  end

  def self.collect_stats
    conn = Sybase.new(@proj)
    h = {
      project_server: conn.project_server,
      project_home: conn.project_home,
      project_name: conn.project_name
    }

    #h[:interpreters] = interpreters(proj)

    version_and_coordsys

    @gxdb = conn.db

    @gxdb.disconnect


  end


  #----------
  #
  def self.process_projects
    begin

      #@mssql.empty_table(@table_name)

      all_projects = []

      @opts[:project_homes].each do |home|
        Discovery.project_list(home, @opts[:deep_scan]).each do |proj|
          @proj = proj
          collect_stats
        end
      end

      #alertable_projects = all_projects.reject{ |x| x[:alerts_summary].empty? }
      #@mssql.write_data(@table_name, alertable_projects)

    rescue Exception => e
      raise e
    end
  end




end

