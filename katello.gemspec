$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "katello/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |gem|
  gem.name        = "katello"
  gem.version     = Katello::VERSION
  gem.license     = 'GPL-2.0'
  gem.authors     = ["N/A"]
  gem.email       = ["katello-devel@redhat.com"]
  gem.homepage    = "http://www.katello.org"
  gem.summary     = "Content and Subscription Management plugin for Foreman"
  gem.description = "Katello adds Content and Subscription Management to Foreman. For this it relies on Candlepin and Pulp."
  gem.required_ruby_version = '~> 2.5'

  gem.files = Dir["{app,webpack,vendor,lib,db,ca,config,locale}/**/*"] +
    Dir['LICENSE.txt', 'README.md', 'package.json']
  gem.files += Dir["engines/bastion/{app,vendor,lib,config}/**/*"]
  gem.files += Dir["engines/bastion/{README.md}"]
  gem.files += Dir["engines/bastion_katello/{app,vendor,lib,config}/**/*"]
  gem.files += Dir["engines/bastion_katello/{README.md}"]
  gem.files -= ["lib/katello/tasks/annotate_scenarios.rake"]
  gem.files -= Dir["locale/**/*.edit.po"]

  gem.require_paths = ["lib"]

  # Core Dependencies
  gem.add_dependency "rails"
  gem.add_dependency "json"
  gem.add_dependency "oauth"
  gem.add_dependency "rest-client"

  gem.add_dependency "rabl"
  gem.add_dependency "foreman-tasks", ">= 5.0"
  gem.add_dependency "foreman_remote_execution", ">= 3.0"
  gem.add_dependency "dynflow", ">= 1.6.1"
  gem.add_dependency "activerecord-import"
  gem.add_dependency "qpid_proton"
  gem.add_dependency "stomp"
  gem.add_dependency "scoped_search", ">= 4.1.9"

  gem.add_dependency "gettext_i18n_rails"
  gem.add_dependency "apipie-rails", ">= 0.5.14"

  gem.add_dependency "fx", "< 1.0"

  gem.add_dependency "pg"

  # Pulp
  gem.add_dependency "runcible", ">= 2.13.0", "< 3.0.0"
  gem.add_dependency "anemone"

  #pulp3
  gem.add_dependency "pulpcore_client", ">= 3.15.0", "< 3.16.0"
  gem.add_dependency "pulp_file_client", ">= 1.10.0", "< 1.11.0"
  gem.add_dependency "pulp_ansible_client", ">= 0.10", "< 0.11"
  gem.add_dependency "pulp_container_client", ">= 2.9.0", "< 2.10.0"
  gem.add_dependency "pulp_deb_client", ">= 2.15.0", "< 2.16.0"
  gem.add_dependency "pulp_rpm_client", ">=3.15.0", "< 3.16.0"
  gem.add_dependency "pulp_certguard_client", "< 2.0"
  gem.add_dependency "pulp_python_client", ">= 3.5.0", "< 3.6.0"
  gem.add_dependency "pulp_ostree_client"

  # UI
  gem.add_dependency "deface", '>= 1.0.2', '< 2.0.0'
  gem.add_dependency "angular-rails-templates", "~> 1.1.0"
  gem.add_development_dependency "uglifier"

  # Testing
  gem.add_development_dependency "factory_bot_rails", "~> 4.5"
  gem.add_development_dependency "minitest-tags"
  gem.add_development_dependency "minitest-reporters"
  gem.add_development_dependency "mocha"
  gem.add_development_dependency "vcr", "< 4.0.0"
  gem.add_development_dependency "webmock"
  gem.add_development_dependency "rubocop-checkstyle_formatter"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "simplecov-rcov"
  gem.add_development_dependency "robottelo_reporter"
end
