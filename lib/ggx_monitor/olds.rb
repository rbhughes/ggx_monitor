require_relative "discovery"
require_relative "sybase"
require "awesome_print"
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
  # Recurse contents of an AOI or layer and get file age stats
  def self.directory_mod_stats(dir_path)

    byte_size = 0
    dir = File.join(dir_path, "**/*")

    ages = Dir.glob(dir).map do |x|
      stat = File.stat(x)
      byte_size += stat.size
      ((Time.now.to_i - stat.mtime.to_i) / 86400).to_i
    end

    return if ages.min < @opts[:skip_days]
    print "."
    creator = creator_from_xml(dir_path)

    {
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


