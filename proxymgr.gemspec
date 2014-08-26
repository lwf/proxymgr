Gem::Specification.new do |gem|
  gem.name          = 'proxymgr'
  gem.version       = '0.1'
  gem.authors       = ['Torbjörn Norinder']
  gem.email         = ['torbjorn@genunix.se']
  gem.description   = %q{Announces services}
  gem.summary       = gem.description
  gem.homepage      = 'https://github.com/campanja/proxymgr'
  gem.platform      = Gem::Platform::RUBY
  gem.add_dependency 'docopt', '~> 0.5.0'
  gem.add_dependency 'zoology'
  gem.add_dependency 'absolute_time'
  gem.add_dependency 'yajl-ruby'
  gem.add_dependency 'zookeeper'
  gem.add_dependency 'state_machine'
  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']
end
