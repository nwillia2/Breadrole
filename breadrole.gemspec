# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "breadrole/version"

Gem::Specification.new do |s|
  s.name        = "breadrole"
  s.version     = Breadrole::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Neil Williams", "Darren Jones"]
  s.email       = ["nwillia2@glam.ac.uk"]
  s.homepage    = "https://github.com/nwillia2/Breadrole"
  s.summary     = %q{Gem Summary}
  s.description = %q{Gem Description}

  s.rubyforge_project = "breadrole"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
