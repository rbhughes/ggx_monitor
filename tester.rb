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
proj = "c:/programdata/geographix/projects"
dir = File.join(proj, "**/{prjlayers.fld,folder.aoi}")

Dir.glob(dir).each do |f| 
  puts f
end
