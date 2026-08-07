# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'intacct_rest'

Gem::Specification.new do |spec|
  spec.name                 = 'intacct-rest'
  spec.version              = IntacctRest::VERSION
  spec.authors              = ['Bernardo Espinoza']
  spec.email                = ['bernardo466@gmail.com']
  spec.summary              = 'A Ruby wrapper for Intacct SAGE Rest API'
  spec.description          = "Allows to use SAGE Rest API for read, create and update SAGE's clients data"

  spec.files                = `git ls-files`.split($/)
  spec.executables          = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files           = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths        = ['lib']

  spec.extra_rdoc_files     = ['README.md', 'LICENSE.txt']
  spec.rdoc_options         = ['--charset=UTF-8']

  spec.required_ruby_version = '>= 3'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'webmock'
end

