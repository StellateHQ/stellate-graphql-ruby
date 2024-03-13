# frozen_string_literal: true

require_relative 'lib/stellate'

Gem::Specification.new do |spec|
  spec.name        = 'stellate'
  spec.version     = Stellate::VERSION
  spec.summary     = 'Integrate Stellate with your GraphQL Ruby API'
  spec.description = <<~DESC
    Add Stellate Metrics Logging and Schema Syncing to your GraphQL Ruby API
    with a few lines of code, click this link for specific set up instructions:
    https://github.com/StellateHQ/stellate-graphql-ruby
  DESC
  spec.authors     = ['Stellate']
  spec.email       = 'eng@stellate.co'
  spec.files       = ['lib/stellate.rb']
  spec.homepage    =
    'https://rubygems.org/gems/stellate'
  spec.license = 'MIT'

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/StellateHQ/stellate-graphql-ruby/issues',
    # 'documentation_uri' => 'https://stellate.co/docs/integrations/graphql-ruby',
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/StellateHQ/stellate-graphql-ruby'
  }

  spec.add_dependency 'net-http', '~> 0.4.1'
  spec.add_dependency 'uri', '~> 0.13.0'
end
