require_relative "discovery"
require_relative "mssql"
require_relative "sybase"
require "filesize"
require "nokogiri"
require "date"
require "yaml"

module Stats
  @table_name = "ggx_stats"
  @proj = nil
  @gxdb = nil

  @table_schema = Proc.new do
    primary_key :id
    String :project_server
    String :project_home
    String :project_name, :null => false
    Fixnum :activity_score
    Bignum :file_count
    Bignum :byte_size
    String :human_size
    DateTime :oldest_file_mod
    DateTime :newest_file_mod
    String :interpreters, :text => true
    String :schema_version
    String :unit_system
    String :db_coordsys, :text => true
    String :map_coordsys, :text => true
    String :esri_coordsys, :text => true
    Bignum :num_wells
    Bignum :num_digital_curves
    Bignum :num_raster_curves
    Bignum :num_formations
    Bignum :num_zone_attr
    Bignum :num_layers_maps
    Bignum :num_dir_surveys
    Bignum :num_sv_interps
    Float :min_longitude
    Float :max_longitude
    Float :min_latitude
    Float :max_latitude
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

  def self.db_stats
    stats = {}

    sql = "select WC, WD, DC, DD, RC, RD, FC, FD, ZC, ZD, YC, YD "\
      "from (select count(*) as WC from well) wc "\
      "cross join "\
      "(select cast(avg(getdate()-row_changed_date) as integer) "\
      "as WD from well) wd "\
      "cross join "\
      "(select count(*) as DC from gx_well_curve) dc "\
      "cross join "\
      "(select cast(avg(getdate()-date_modified) as integer) "\
      "as DD from gx_well_curve) dd "\
      "cross join "\
      "(select count(*) as RC from log_image_reg_log_section) rc "\
      "cross join "\
      "(select cast(avg(getdate()-update_date) as integer) "\
      "as RD from log_image_reg_log_section) rd "\
      "cross join "\
      "(select count(distinct(source+formation)) as FC from formations) fc "\
      "cross join "\
      "(select cast(avg(getdate()-f.[Row Changed Date]) "\
      "as integer) as FD from formations f) fd "\
      "cross join "\
      "(select count(distinct z.[Attribute Name]) "\
      "as ZC from wellzoneintrvvaluewithdepthsouterjoin z) zc "\
      "cross join "\
      "(select cast(avg(getdate()-z.[Data Date]) as integer) "\
      "as ZD from wellzoneintrvvaluewithdepthsouterjoin z) zd "\
      "cross join "\
      "(select count(distinct y.[Survey ID]) as YC from wellsurveys y) yc "\
      "cross join "\
      "(select cast(avg(getdate()-y.[Row Changed Date]) as integer) "\
      "as YD from wellsurveydir y) yd"

    @gxdb[sql].all.each do |x|
      stats[:num_wells] =          x[:wc]
      stats[:age_wells] =          x[:wd]
      stats[:num_digital_curves] = x[:dc]
      stats[:age_digital_curves] = x[:dd]
      stats[:num_raster_curves] =  x[:rc]
      stats[:age_raster_curves] =  x[:rd]
      stats[:num_formations] =     x[:fc]
      stats[:age_formations] =     x[:fd]
      stats[:num_zone_attr] =      x[:zc]
      stats[:age_zone_attr] =      x[:zd]
      stats[:num_dir_surveys] =    x[:yc]
      stats[:age_dir_surveys] =    x[:yd]
    end

    stats
    
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

    age_layers_maps = (map_ago.inject(:+).to_f / map_ago.size).round rescue nil
    age_sv_interps = (sei_ago.inject(:+).to_f / sei_ago.size).round rescue nil
    age_file_mod = (file_ago.inject(:+).to_f / file_ago.size).round rescue nil

    {
      num_layers_maps: map_num,
      num_sv_interps: sei_num,
      oldest_file_mod: oldest_file_mod,
      newest_file_mod: newest_file_mod,
      byte_size: byte_size,
      human_size: Filesize.from("#{byte_size} B").pretty.gsub('i',''),
      file_count: file_count,
      age_layers_maps: age_layers_maps,
      age_sv_interps: age_sv_interps,
      age_file_mod: age_file_mod
    }

  end

  #----------
  #
  def self.surface_extents

    sql = "select "\
      "min(surface_longitude) as min_longitude, "\
      "min(surface_latitude) as min_latitude, "\
      "max(surface_longitude) as max_longitude, "\
      "max(surface_latitude) as max_latitude "\
      "from well where "\
      "surface_longitude between -180 and 180 and "\
      "surface_latitude between -90 and 90 and "\
      "surface_longitude is not null and "\
      "surface_latitude is not null"

    @gxdb[sql].all[0]
    
  end


  def self.collect_stats

    project_server = Discovery.parse_host(@proj)
    project_home = Discovery.parse_home(@proj)
    project_name = File.basename(@proj)

    print "ggx_stats --> #{project_server}/#{project_home}/#{project_name}"

    @gxdb = Sybase.new(@proj).db

    stats = {
      project_server: project_server,
      project_home: project_home,
      project_name: project_name
    }

    stats.merge! interpreters
    print "."
    stats.merge! version_and_coordsys
    print "."
    stats.merge! file_stats
    print "."
    stats.merge! db_stats
    print "."
    stats.merge! surface_extents
    print "."

    ages = stats.select{ |k,v| k.to_s.match /^age/ }.values.compact
    stats = stats.reject{ |k,v| k.to_s.match /^age/ }

    stats[:activity_score] = ages.inject(:+)/ages.size

    @gxdb.disconnect
    puts
    return stats
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
          all_projects << collect_stats
        end
      end

      @mssql.write_data(@table_name, all_projects)

    rescue Exception => e
      raise e
    end
  end




end

