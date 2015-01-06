=begin
require 'yaml'


opts = {
  thing_a: true,
  thing_b: false
}

opts_path = "c:/dev/ggx_monitor/options.yml"

x = YAML.load_file(opts_path)
x = x[:olds].merge opts
puts x
#puts x[:olds][:project_homes]
#
=end
#proj = "c:/programdata/geographix/projects"
#dir = File.join(proj, "**/{prjlayers.fld,folder.aoi}")
#
#Dir.glob(dir).each do |f| 
#  puts f
#end

path = "//OKC1GGX0001/Discovery-24ef556b-b44e-4570-a7d8-c4f89ca5e12c$/California/Global/Well Spots"

path = "//OKC1GGX0001/Discovery-24ef556b-b44e-4570-a7d8-c4f89ca5e12c$/California/User Files"

path = "//OKC1GGX0001/Discovery-24ef556b-b44e-4570-a7d8-c4f89ca5e12c$/California/Global"

path = "//OKC1GGX0001/Discovery-9e38daeb-cea5-4963-96dd-e11f6c1b780e$/East Texas/Brazos_Grimes_Madison/Fields_IHS"

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


require "digest/md5"

def layer_checksum(layer)
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

puts layer_checksum path

#----------
# Calculate
=begin
  def composite_checksum(path)
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
        File.open(p, "r") do |f|
          s << f.read(limit)
        end
      end
    end
puts s.size
    Digest::MD5.hexdigest(s)
  end
=end

