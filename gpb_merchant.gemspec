# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gpb_merchant/version'

Gem::Specification.new do |spec|
  spec.name          = "gpb_merchant"
  spec.version       = GpbMerchant::VERSION
  spec.authors       = ["Stanislav Ershov", "Tyralion"]
  spec.email         = ["digital.stream.of.mind@gmail.com", "piliaiev@gmail.com"]
  spec.description   = %q{Api for e-card GazPromBank}
  spec.summary       = %q{Api for e-card GazPromBank}
  spec.homepage      = ""
  spec.license       = "BSD"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency "nokogiri", "~> 1.5"
  spec.add_dependency "rails",    ">= 3.2"

end
