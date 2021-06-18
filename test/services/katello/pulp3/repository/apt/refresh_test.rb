require 'katello_test_helper'

module Katello
  module Service
    class Repository
      class Apt
        class RefreshDistributionTest < ::ActiveSupport::TestCase
          include Katello::Pulp3Support

          def setup
            User.current = User.anonymous_admin
            @primary = FactoryBot.create(:smart_proxy, :default_smart_proxy, :with_pulp3)
            @repo = katello_repositories(:debian_9_amd64)
            create_repo(@repo, @primary)
            @service = Katello::Pulp3::Repository::Apt.new(@repo, @primary)

            ::ForemanTasks.sync_task(Actions::Pulp3::Repository::RefreshDistribution, @repo, @primary)
          end

          def teardown
            User.current = User.anonymous_admin
            ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::Delete, @repo, @primary)
          end

          def test_needs_distributor_update
            refute @service.distribution_needs_update?
            @repo.relative_path = "/some/other/path/that/is/different/"
            @repo.save!
            assert @service.distribution_needs_update?
          end

          def test_updates
            @service.refresh_if_needed
            @repo.relative_path = "/some/other/path/that/is/different"
            @repo.root.url = 'http://foo.com/bar'
            @repo.save!
            refresh_tasks = @service.refresh_if_needed
            refresh_tasks.compact.each { |task| wait_on_task(@primary, task) }
            assert @repo.relative_path, @service.get_distribution.base_path
          end
        end
      end
    end
  end
end
