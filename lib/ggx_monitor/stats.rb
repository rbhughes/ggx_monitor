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
    Fixnum :activity_score
    String :full_path
    Bignum :file_count
    Bignum :byte_size
    String :human_size
    DateTime :oldest_file_mod
    DateTime :newest_file_mod
    Fixnum :avg_file_mod
    String :surface_bounds
    String :interpreters, :text => true
    String :schema_version
    String :unit_system
    String :db_coordsys
    String :map_coordsys
    String :esri_coordsys
    Bignum :num_wells
    Bignum :num_digital_curves
    Bignum :num_raster_curves
    Bignum :num_formations
    Bignum :num_zone_attr
    Bignum :num_layers_maps
    Bignum :num_dir_surveys
    Bignum :num_sv_interps
    Fixnum :avg_wells
    Fixnum :avg_digital_curves
    Fixnum :avg_raster_curves
    Fixnum :avg_formations
    Fixnum :avg_zone_attr
    Fixnum :avg_layers_maps
    Fixnum :avg_dir_surveys
    Fixnum :avg_sv_interps
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
    ints = Dir.glob(File.join(uf,"*")).map{ |f| File.basename(f) }.join(", ")
    { interpreters: ints }
  end

  #----------
  #
  def self.version_and_coordsys
    pxml = File.join(@proj, "Project.ggx.xml")
    return unless File.exists?(pxml)

    f = File.open(pxml)
    doc = Nokogiri::XML(f)
    f.close

    schema_vers = doc.xpath("ggx/Project/ProjectVersion").inner_text
    db_sys = doc.xpath("ggx/Project/StorageCoordinateSystem/GGXC1").inner_text
    map_sys = doc.xpath("ggx/Project/DisplayCoordinateSystem/GGXC1").inner_text
    esri_sys = doc.xpath("ggx/Project/DisplayCoordinateSystem/ESRI").inner_text
    unit_sys = doc.xpath("ggx/Project/UnitSystem").inner_text

    {
      schema_version: schema_vers.squeeze,
      db_coordsys: db_sys.squeeze,
      map_coordsys: map_sys.squeeze,
      esri_coordsys: "ESRI::"+esri_sys.squeeze,
      unit_system: unit_sys.squeeze
    }
  end

    #Bignum :num_wells
    #Bignum :num_digital_curves
    #Bignum :num_raster_curves
    #Bignum :num_formations
    #Bignum :num_zone_attr
    #Bignum :num_layers_maps
    #Bignum :num_dir_surveys
    #Bignum :num_sv_interps
    #Fixnum :avg_wells
    #Fixnum :avg_digital_curves
    #Fixnum :avg_raster_curves
    #Fixnum :avg_formations
    #Fixnum :avg_zone_attr
    #Fixnum :avg_layers_maps
    #Fixnum :avg_dir_surveys
    #Fixnum :avg_sv_interps

  def self.db_stats
    sql = "select "\
      "num_wells, avg_wells, "\
      "num_digital_curves, avg_digital_curves, "\
      "num_raster_curves, avg_raster_curves, "\
      "num_formations, avg_formations, "\
      "num_zone_attr, avg_zone_attr, "\
      "num_dir_surveys, avg_dir_surveys "\
      "from (select count(*) as num_wells from well) wc "\
      "cross join (select avg(row_changed_date) as avg_wells from well) wd "\
      "cross join (select count(*) as num_digital_curves from gx_well_curve) dc "\
      "cross join (select max(date_modified) as avg_digital_curves from gx_well_curve) dd "\
      "cross join (select count(*) as num_raster_curves from log_image_reg_log_section) rc "\
      "cross join (select max(update_date) as avg_raster_curves "\
      "from log_image_reg_log_section) rd "\
      "cross join (select count(distinct(source+formation)) as num_formations "\
      "from formations) fc "\
      "cross join (select max(f.[Row Changed Date]) as avg_formations "\
      "from formations f) fd "\
      "cross join (select count(distinct zc.[Attribute Name]) as num_zone_attr "\
      "from wellzoneintrvvaluewithdepthsouterjoin zc) zc "\
      "cross join (select max(zd.[Data Date]) as avg_zone_attr "\
      "from wellzoneintrvvaluewithdepthsouterjoin zd) zd "\
      "cross join (select count(distinct yc.[Survey ID]) as num_dir_surveys "\
      "from wellsurveys yc) yc "\
      "cross join (select max(yd.[Row Changed Date]) as avg_dir_surveys "\
      "from wellsurveydir yd) yd"

    @gxdb[sql].all.each do |x|
      puts x[:avg_wells]
    end
    
  end



  #----------
  #
  def self.file_stats
    dir = File.join(@proj, "**/*")

    map_num, sei_num, file_count, byte_size = 0, 0, 0, 0 
    sei_ago, map_ago, file_ago = [], [], []

    oldest_file_mod = Time.now
    newest_file_mod = Time.at(0)

    Dir.glob(dir, File::FNM_DOTMATCH).each do |f| 
      stat = File.stat(f)
      days_ago = ((Time.now.to_i - stat.mtime.to_i) / 86400).to_i
      byte_size += stat.size
      file_count += 1 if File.file?(f)
      oldest_file_mod = stat.mtime if stat.mtime < oldest_file_mod
      newest_file_mod = stat.mtime if stat.mtime > newest_file_mod

      file_ago << days_ago unless f.match /gxdb.*\.(db|log)$/i

      if f.match /\interp\.svx$/i
        sei_num += 1
        sei_ago << days_ago
      end

      if f.match /\.(gmp|shp)$/i
        map_num += 1
        map_ago << days_ago
      end

    end

    avg_layers_maps = (map_ago.inject(:+).to_f / map_ago.size).round rescue nil
    avg_sv_interps = (sei_ago.inject(:+).to_f / sei_ago.size).round rescue nil
    avg_file_mod = (file_ago.inject(:+).to_f / file_ago.size).round rescue nil

    {
      map_num: map_num,
      sei_num: sei_num,
      oldest_file_mod: oldest_file_mod,
      newest_file_mod: newest_file_mod,
      byte_size: byte_size,
      file_count: file_count,
      avg_layers_maps: avg_layers_maps,
      avg_sv_interps: avg_sv_interps,
      avg_file_mod: avg_file_mod
    }

  end


  def self.collect_stats
    conn = Sybase.new(@proj)
    @gxdb = conn.db

    h = {
      project_server: conn.project_server,
      project_home: conn.project_home,
      project_name: conn.project_name
    }

    #interpreters
    #version_and_coordsys
    #file_stats
    db_stats


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

