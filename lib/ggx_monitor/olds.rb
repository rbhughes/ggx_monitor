require_relative "discovery"
require_relative "sybase"
require "awesome_print"
require "digest/md5"
require "filesize"
require "nokogiri"
require "date"
require "csv"

module Olds

  @proj = nil

  # kinda like mattr_accessor, but define @mssql too
  def self.set_opts=(options)
    @opts = options
  end


  #----------
  #
  def self.collect_filestats

    @project_server = Discovery.parse_host(@proj)
    @project_home = Discovery.parse_home(@proj)
    @project_name = File.basename(@proj)

    stats = []

    print "ggx_olds --> #{@project_server}/#{@project_home}/#{@project_name}"
    
    dir = File.join(@proj, "**/*")
    regex = /.*/

    case @opts[:type]
    when :aoi
      dir = File.join(@proj, "**/{prjlayers.fld,folder.aoi}")
    when :layer
      dir = File.join(@proj, "**/{layer.gly}")
    when :log
      regex = Regexp.union [
        /database rebuild log\.txt$/i,
        /formationcalc\.txt$/i,
        /glacurveloadlog\.txt$/i,
        /well spotting log\.txt$/i,
        /las_import\.log$/i,
        /batchimport\.log$/i,
        /bulk wellbase layer update\.log$/i,
        /devcalc\.log$/i,
        /drimportfiles\.log$/i,
        /drmigration\.log$/i,
        /ggxxla\.log$/i,
        /import\.log$/i,
        /mrufiles\.log$/i,
        /recreateextents\.log$/i,
        /subsetcombine\.log$/i,
        /zone-.*calculations\.log$/i,
      ]
    when :user
      dir = File.join(@proj, "User Files", "*")
    else
      puts "how did you do that?"
    end

    Dir.glob(dir).each do |f| 
      next unless File.exists?(f)

      if @opts[:type] == :log
        element = file_mod_stats(f) if f.match regex
        print "."
        stats << element unless element.nil?
      else
        # use parent dir for layers and aois. use f if user
        target = (@opts[:type] == :user) ? f : File.dirname(f)
        element = directory_mod_stats(target)
        stats << element unless element.nil?
      end

    end

    puts
    stats
  end


  #----------
  # Extract the creator/owner of the layer or aoi from its xml file if present
  # Use the project creator as owner of the Global AOI
  def self.creator_from_xml(dir)
    xml, xpath, creator = nil, nil, nil

    if @opts[:type] == :aoi

      if (dir.match /global$/i)
        xml = File.join(File.dirname(dir), "project.ggx.xml")
        xpath = "ggx/Project/CreatedBy"
      else
        xml = File.join(dir, "folder.aoi.xml")
        xpath = "aoi/AreaOfInterest/CreatedBy"
      end

    elsif @opts[:type] == :layer

      xml = File.join(dir, "layer.gly.xml")
      xpath = "gly/Layer/Attributes/CreatedBy"

    elsif @opts[:type] == :user
      # just use "User Files/<name>"
      creator = File.basename(dir)
    end

    if ! xml.nil? && File.exists?(xml)
      f = File.open(xml)
      doc = Nokogiri::XML(f)
      f.close
      creator = doc.xpath(xpath).inner_text
    end

    creator
  end

  #----------
  # Calculate checksum from single or multiple files. Collect only bytes less 
  # than the cs_max limit to keep things fast (do not use on huge directories;
  # this is intended for use on GGX layers and the like).
  # NOT PRACTICAL, but keep this around in case...
=begin
  def self.composite_checksum(path)
    return unless File.exists?(path)
    cs_max = 1024**2 * 2 #size in MiB
    s = ""

    if File.file?(path)
      limit = (File.size(path) > cs_max) ? cs_max : File.size(path)
      File.open(path, "r") do |f|
        s << f.read(limit)
      end
    elsif File.directory?(path)
      Dir.glob(File.join(path,"**/*")).each do |p|
        next unless File.exists?(p) && File.file?(p)
        limit = (File.size(p) > cs_max) ? cs_max : File.size(p)
        File.open(path, "r") do |f|
          s << f.read(limit) #if File.file?(p)
        end
      end
    end

    Digest::MD5.hexdigest(s)
  end
=end

  #----------
  # We want to identify duplicate GGX layers, so check each of the shapefile
  # components separately (and ignore .xml and .prj) to get data only
  def self.layer_checksum(layer)
    cs_max = 1024**2 * 2 #size in MiB
    s = ""
    matches = "{shp,shp.xml,dbf,shx,sbn,sbx}"
    Dir.glob(File.join(layer, "**/*.#{matches}")).each do |f|
      next unless File.exists?(f)
      limit = (File.size(f) > cs_max) ? cs_max : File.size(f)
      File.open(f, "r") do |x| 
        s << x.read(limit) if File.file?(x)
      end
    end
    Digest::MD5.hexdigest(s)
  end


  #----------
  # Recurse contents of an AOI or layer and get file age stats
  def self.directory_mod_stats(dir_path)

    byte_size = 0
    dir = File.join(dir_path, "**/*")

    ages = Dir.glob(dir).map do |f|
      next unless File.exists?(f)
      stat = File.stat(f)
      byte_size += stat.size
      ((Time.now.to_i - stat.mtime.to_i) / 86400).to_i
    end

    return if ages.min < @opts[:skip_days]
    print "."
    creator = creator_from_xml(dir_path)

    stats = {
      project_server: @project_server,
      project_home: @project_home,
      project_name: @project_name,
      creator: creator,
      type: @opts[:type].to_s,
      path: dir_path,
      total_size: Filesize.from("#{byte_size} B").pretty.gsub('i',''),
      min_mod: ages.min,
      max_mod: ages.max,
      avg_mod: ((ages.inject(:+).to_f / ages.size).round rescue nil)
    }

    stats[:checksum] = layer_checksum(dir_path) if @opts[:type] == :layer
    return stats
  end


  #----------
  # use for log files
  def self.file_mod_stats(file_path)
    stat = File.stat(file_path)
    byte_size = stat.size
    max_mod = ((Time.now.to_i - stat.mtime.to_i) / 86400).to_i

    return if max_mod < @opts[:skip_days]
    print "."

    {
      project_server: @project_server,
      project_home: @project_home,
      project_name: @project_name,
      type: @opts[:type].to_s,
      path: file_path,
      total_size: Filesize.from("#{byte_size} B").pretty.gsub('i',''),
      max_mod: max_mod
    }
  end
  


  #----------
  #
  def self.process_projects
    begin

      age_stats = []

      @opts[:project_homes].each do |home|
        Discovery.project_list(home, @opts[:deep_scan]).each do |proj|
          @proj = proj
          age_stats.concat collect_filestats
        end
      end

      sorted = age_stats.sort_by {|x| x[:max_mod]}.reverse

      if @opts[:csv_out]
        CSV.open(@opts[:csv_out], "wb") do |csv|
          csv << sorted[0].keys
          sorted.each do |h|
            csv << h.values
          end
        end
        puts "\n\nCSV file written to: #{@opts[:csv_out]}"
      else
        ap sorted
      end

    rescue Exception => e
      raise e
    end
  end

  
end
