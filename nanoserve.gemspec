# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        =  'nanoserve'
  s.version     =  '0.1.0'
  s.licenses    =  ['3BSD']
  s.summary     =  'Listen to one-shot connections'
  s.authors     =  ['Loic Nageleisen']
  s.email       =  'loic.nageleisen@gmail.com'
  s.files       =  Dir['lib/**/*.rb'] + Dir['bin/*']
  s.files      +=  Dir['[A-Z]*'] + Dir['test/**/*']
  s.description =  <<-EOT
    NanoServe allows you to wait for an external call and act on it.
  EOT

  s.required_ruby_version = '>= 2.3'

  s.add_development_dependency 'minitest', '~> 5.10'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake', '~> 12.0'
end
