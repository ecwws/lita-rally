Gem::Specification.new do |spec|
  spec.name          = 'lita-rally'
  spec.version       = '1.2.0'
  spec.authors       = ['Richard Li']
  spec.email         = ['evilcat@wisewolfsolutions.com']
  spec.description   = %q{Rally plugin for lita bot}
  spec.summary       = %q{lita bot Rally plugin}
  spec.homepage      = 'https://github.com/ecwws/lita-rally'
  spec.license       = 'MIT'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'lita', '~> 4.1'
  spec.add_runtime_dependency 'rest-client', '>= 0'
  spec.add_runtime_dependency 'json', '>= 0'
  spec.add_runtime_dependency 'rally_api', '~> 1.1', '>= 1.1.2'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake', '~> 0'
  spec.add_development_dependency 'rack-test', '~> 0'
  spec.add_development_dependency 'rspec', '~> 3.0', '>= 3.0.0'
end
