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
  #
  def self.collect_filestats

    project_server = Discovery.parse_host(@proj)
    project_home = Discovery.parse_home(@proj)
    project_name = File.basename(@proj)

    print "ggx_olds --> #{project_server}/#{project_home}/#{project_name}"
    
    puts #REMOVE ME

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
        /^TS_TEMP.*/i
      ]
    when :user
      dir = File.join(@proj, "User Files", "**/*")
    else
    end

    #dir = File.join(@proj, "**/*")

    #oldest_file_mod = Time.now
    #newest_file_mod = Time.at(0)

    puts "----"
    puts dir
    puts "----"

    #Dir.glob(dir, File::FNM_DOTMATCH).each do |f| 
    Dir.glob(dir).each do |f| 
      stat = File.stat(f)
      days_ago = ((Time.now.to_i - stat.mtime.to_i) / 86400).to_i

      puts f


      #byte_size += stat.size
      #file_count += 1 if File.file?(f)
      #oldest_file_mod = stat.mtime if stat.mtime < oldest_file_mod
      #newest_file_mod = stat.mtime if stat.mtime > newest_file_mod

      #file_ago << days_ago unless f.match /gxdb.*\.(db|log)$/i

      #if f.match /\.(gmp|shp)$/i
      #  map_num += 1
      #  map_ago << days_ago
      #end

    end


    puts
  end

  #----------
  #
  def self.process_projects
    begin


      @opts[:project_homes].each do |home|
        Discovery.project_list(home, @opts[:deep_scan]).each do |proj|
          @proj = proj
          collect_filestats

        end
      end

      #@opts[:days_ago] = days_ago


    rescue Exception => e
      raise e
    end
  end

  
end


