# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ggx_monitor/version'

Gem::Specification.new do |spec|
  spec.name          = "ggx_monitor"
  spec.version       = GgxMonitor::VERSION
  spec.authors       = ["R. Bryan Hughes"]
  spec.email         = ["rbhughes@logicalcat.com"]
  spec.summary       = %q{monitor geographix projects at sandridge}
  spec.description   = %q{newlogs, alerts, stats}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  #spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.executables   = ['ggx_newlogs','ggx_alerts','ggx_stats', 'ggx_temps']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "sequel", "~> 4.17"
  spec.add_dependency "tiny_tds", "~> 0.6"
  spec.add_dependency "sqlanywhere", "~> 0.1"
  spec.add_dependency "nokogiri", "~> 1.6"
  spec.add_dependency "filesize", "~> 0.0"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
