require 'yaml'

x = YAML.load_file('./settings.yml')

puts x[:alerts][:project_homes][0]
