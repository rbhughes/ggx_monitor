
module Discovery

#  def self.project_list(root, deep_scan)
#    s = Walker.new
#    s.ggx_projects(root, deep_scan)
#  end

  def self.project_list(root, deep_scan)
    root = root.gsub("\\","/")
    projects = []
    recurse = deep_scan ? "**" : "*"
    Dir.glob(File.join(root, recurse, "*.ggx")).each do |ggx|
      proj = File.dirname(ggx)
      projects << proj  if is_ggx_project?(proj)
    end
    projects
  end

  private

  def self.is_ggx_project?(path) 
    a = File.join(path, "gxdb.db")
    b = File.join(path, "Global")
    return (File.exists?(a) && File.exists?(b)) ? true : false
  end

=begin
    def total_bytes(path)
      dir = File.join(path, "**/*")
      Dir.glob(dir, File::FNM_DOTMATCH).select{|f| File.file?(f)}.map do |j|
        if File.exists?(j) && File.readable?(j)
          File.stat(j).size ||= 0
        else
          puts "COULD NOT READ  #{j}"
          0
        end
      end.inject(:+)
    end
=end



=begin
  class Walker 


    def ggx_projects(root, deep_scan)
      #stats = []
      root = root.gsub("\\","/")
      projects = []

      recurse = deep_scan ? "**" : "*"

      Dir.glob(File.join(root, recurse, "*.ggx")).each do |ggx|
        proj = File.dirname(ggx)

        if is_ggx_project?(proj)
          #proj_size = total_bytes(proj)
          #aoi_stats(proj).each do |stat|
          #  stat[:project] = proj
          #  stat[:proj_size] = proj_size
          #  stats << stat
          #  ap stat
          #end
          #puts "#{proj} --- #{proj_size}"
          projects << proj

        end
      end
      projects

      #if stats.empty?
      #  puts "sorry, no AOIs found"
      #  return
      #end


      #CSV.open(ARGV[1], "wb") do |csv|
      #  csv << stats[0].keys
#
#        stats.each do |s|
#          csv << s.values
#        end
#      end


    end

    private

    def is_ggx_project?(path) 
      a = File.join(path, "gxdb.db")
      b = File.join(path, "Global")
      return (File.exists?(a) && File.exists?(b)) ? true : false
    end

    def total_bytes(path)
      dir = File.join(path, "**/*")
      Dir.glob(dir, File::FNM_DOTMATCH).select{|f| File.file?(f)}.map do |j|
        if File.exists?(j) && File.readable?(j)
          File.stat(j).size ||= 0
        else
          puts "COULD NOT READ  #{j}"
          0
        end
      end.inject(:+)
    end

  end

=end



end

