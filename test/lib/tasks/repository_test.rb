require 'katello_test_helper'
require 'rake'

module Katello
  class RepositoryTaskTest < ActiveSupport::TestCase
    def setup
      FactoryBot.create(:smart_proxy, :default_smart_proxy, :with_pulp3)

      Rake.application.rake_require 'katello/tasks/repository'
      Rake.application.rake_require 'katello/tasks/reimport'

      Rake::Task['katello:regenerate_repo_metadata'].reenable
      Rake::Task['katello:refresh_pulp_repo_details'].reenable
      Rake::Task['katello:correct_repositories'].reenable
      Rake::Task['katello:disable_dynflow'].reenable
      Rake::Task['katello:correct_puppet_environments'].reenable
      Rake::Task['katello:check_ping'].reenable
      Rake::Task['katello:change_download_policy'].reenable
      Katello::Ping.expects(:ping).returns(:status => 'ok')

      Rake::Task.define_task(:environment)

      @library_repo = katello_repositories(:fedora_17_x86_64)
      ::Katello::Pulp3::RepositoryReference.new(repository_href: "test_repo_1/", root_repository_id: @library_repo.root_id, content_view_id: @library_repo.content_view.id).save
      @cv_repo = katello_repositories(:fedora_17_dev_library_view)
      ::Katello::Pulp3::RepositoryReference.new(repository_href: "test_repo_2/", root_repository_id: @cv_repo.root_id, content_view_id: @cv_repo.content_view.id).save

      @puppet_env = katello_content_view_puppet_environments(:dev_view_puppet_environment)

      Katello::Repository.where("id not in (#{@library_repo.id},#{@cv_repo.id})").destroy_all
      Katello::ContentViewPuppetEnvironment.where("id != #{@puppet_env.id}").destroy_all
      ENV['COMMIT'] = nil
      ENV['CONTENT_VIEW'] = nil
      ENV['LIFECYCLE_ENVIRONMENT'] = nil
    end

    def test_publish_unpublished_repositories
      Katello::Repository.any_instance.stubs(:needs_metadata_publish?).returns(true)

      Rake.application.invoke_task('katello:publish_unpublished_repositories')
    end

    def test_regenerate_repo_metadata
      ForemanTasks.expects(:async_task).with(::Actions::Katello::Repository::BulkMetadataGenerate,
                                             Katello::Repository.all.order_by_root(:name)).returns(ForemanTasks::Task::DynflowTask::DynflowTask.new)

      Rake.application.invoke_task('katello:regenerate_repo_metadata')
    end

    def test_regenerate_repo_metadata_env
      ENV['LIFECYCLE_ENVIRONMENT'] = @library_repo.environment.name

      expected_repos = Katello::Repository.in_environment(@library_repo.environment).order_by_root(:name)
      Katello::Repository.stubs(:in_environment).returns(expected_repos)
      ForemanTasks.expects(:async_task).with(::Actions::Katello::Repository::BulkMetadataGenerate,
                                             expected_repos).returns(ForemanTasks::Task::DynflowTask.new)

      Rake.application.invoke_task('katello:regenerate_repo_metadata')
    end

    def test_regenerate_repo_metadata_cv
      ENV['CONTENT_VIEW'] = @cv_repo.content_view.name
      ForemanTasks.expects(:async_task).with(::Actions::Katello::Repository::BulkMetadataGenerate,
                                             [@cv_repo]).returns(ForemanTasks::Task::DynflowTask.new)

      Rake.application.invoke_task('katello:regenerate_repo_metadata')
    end

    def test_refresh_pulp_repo_details
      ForemanTasks.expects(:async_task).with(::Actions::BulkAction, Actions::Katello::Repository::RefreshRepository,
                                             Katello::Repository.all.order_by_root(:name)).returns(ForemanTasks::Task::DynflowTask.new)

      Rake.application.invoke_task('katello:refresh_pulp_repo_details')
    end

    def test_correct_repositories
      ENV['CONTENT_VIEW'] = @cv_repo.content_view.name
      Runcible::Extensions::Repository.any_instance.expects(:retrieve).once.with(@cv_repo.pulp_id).returns({})
      SmartProxy.any_instance.stubs(:pulp3_support?).returns(false)

      ForemanTasks.expects(:sync_task).never

      Rake.application.invoke_task('katello:correct_repositories')
    end

    def test_correct_repositories_missing_cv_repo
      ENV['CONTENT_VIEW'] = @cv_repo.content_view.name
      Runcible::Extensions::Repository.any_instance.expects(:retrieve).once.with(@cv_repo.pulp_id).raises(RestClient::ResourceNotFound)
      SmartProxy.any_instance.stubs(:pulp3_support?).returns(false)

      ForemanTasks.expects(:sync_task).never

      Rake.application.invoke_task('katello:correct_repositories')
    end

    def test_correct_repositories_missing_cv_repo_commit
      ENV['CONTENT_VIEW'] = @cv_repo.content_view.name
      ENV['COMMIT'] = 'true'
      Runcible::Extensions::Repository.any_instance.expects(:retrieve).once.with(@cv_repo.pulp_id).raises(RestClient::ResourceNotFound)
      SmartProxy.any_instance.stubs(:pulp3_support?).returns(false)

      ForemanTasks.expects(:sync_task).with(::Actions::Katello::Repository::Destroy, @cv_repo)

      Rake.application.invoke_task('katello:correct_repositories')
    end

    def test_correct_repositories_missing_library_repo_commit
      ENV['LIFECYCLE_ENVIRONMENT'] = @library_repo.environment.name
      ENV['COMMIT'] = 'true'

      Katello::Repository.stubs(:in_environment).returns(Katello::Repository.where(:id => @library_repo))
      Runcible::Extensions::Repository.any_instance.expects(:retrieve).once.with(@library_repo.pulp_id).raises(RestClient::ResourceNotFound)
      SmartProxy.any_instance.stubs(:pulp3_support?).returns(false)

      ForemanTasks.expects(:sync_task).with(::Actions::Katello::Repository::Create, @library_repo)

      Rake.application.invoke_task('katello:correct_repositories')
    end

    def test_correct_repositories_pulp3
      ENV['CONTENT_VIEW'] = @cv_repo.content_view.name
      PulpRpmClient::RepositoriesRpmApi.any_instance.expects(:read).once.with("test_repo_2/").returns({})

      ForemanTasks.expects(:sync_task).never

      Rake.application.invoke_task('katello:correct_repositories')
    end

    def test_correct_repositories_missing_cv_repo_pulp3
      ENV['CONTENT_VIEW'] = @cv_repo.content_view.name
      PulpRpmClient::RepositoriesRpmApi.any_instance.expects(:read).once.with("test_repo_2/").raises(PulpRpmClient::ApiError)

      ForemanTasks.expects(:sync_task).never

      Rake.application.invoke_task('katello:correct_repositories')
    end

    def test_correct_repositories_missing_cv_repo_commit_pulp3
      ENV['CONTENT_VIEW'] = @cv_repo.content_view.name
      ENV['COMMIT'] = 'true'
      PulpRpmClient::RepositoriesRpmApi.any_instance.expects(:read).once.with("test_repo_2/").raises(PulpRpmClient::ApiError)

      ForemanTasks.expects(:sync_task).with(::Actions::Katello::Repository::Destroy, @cv_repo)

      Rake.application.invoke_task('katello:correct_repositories')
    end

    def test_correct_repositories_missing_library_repo_commit_pulp3
      ENV['LIFECYCLE_ENVIRONMENT'] = @library_repo.environment.name
      ENV['COMMIT'] = 'true'

      Katello::Repository.stubs(:in_environment).returns(Katello::Repository.where(:id => @library_repo))
      PulpRpmClient::RepositoriesRpmApi.any_instance.expects(:read).once.with("test_repo_1/").raises(PulpRpmClient::ApiError)

      ForemanTasks.expects(:sync_task).with(::Actions::Katello::Repository::Create, @library_repo)

      Rake.application.invoke_task('katello:correct_repositories')
    end

    def test_destroy_missing_root_repo
      ENV['CONTENT_VIEW'] = @cv_repo.content_view.name
      ENV['COMMIT'] = 'true'

      root = ::Katello::RootRepository.create(label: "a_root_repo", name: "A Root Repo", download_policy: "immediate",
                                              product_id: ::Katello::Product.all.min.id)
      PulpRpmClient::RepositoriesRpmApi.any_instance.expects(:read).once.with("test_repo_2/").returns({})

      Rake.application.invoke_task('katello:correct_repositories')

      assert_raise ActiveRecord::RecordNotFound do
        root.reload
      end
    end

    def test_correct_puppet_environments
      ENV['CONTENT_VIEW'] = @puppet_env.content_view.name
      Runcible::Extensions::Repository.any_instance.expects(:retrieve).once.with(@puppet_env.pulp_id).returns({})

      ForemanTasks.expects(:sync_task).never

      Rake.application.invoke_task('katello:correct_puppet_environments')
    end

    def test_correct_puppet_environments_missing
      ENV['CONTENT_VIEW'] = @puppet_env.content_view.name
      Runcible::Extensions::Repository.any_instance.expects(:retrieve).once.with(@puppet_env.pulp_id).raises(RestClient::ResourceNotFound)

      ForemanTasks.expects(:sync_task).never
      Rake.application.invoke_task('katello:correct_puppet_environments')
    end

    def test_correct_puppet_environments_missing_commit
      ENV['COMMIT'] = 'true'
      ENV['CONTENT_VIEW'] = @puppet_env.content_view.name
      Runcible::Extensions::Repository.any_instance.expects(:retrieve).once.with(@puppet_env.pulp_id).raises(RestClient::ResourceNotFound)

      ForemanTasks.expects(:sync_task).with(::Actions::Katello::ContentViewPuppetEnvironment::Create, @puppet_env)

      Rake.application.invoke_task('katello:correct_puppet_environments')
    end

    def test_change_download_policy
      ENV['DOWNLOAD_POLICY'] = 'background'
      Katello::Repository.stubs(:yum_type).returns(Katello::Repository.where(:id => @library_repo))
      ForemanTasks.expects(:sync_task).with(::Actions::Katello::Repository::Update,
                                            @library_repo.root,
                                            download_policy: 'background')

      Rake.application.invoke_task('katello:change_download_policy')
    end

    def test_change_download_policy_bad_policy
      ForemanTasks.expects(:sync_task).never

      ENV['DOWNLOAD_POLICY'] = nil
      Rake.application.invoke_task('katello:change_download_policy')

      ENV['DOWNLOAD_POLICY'] = 'invalid'
      Rake.application.invoke_task('katello:change_download_policy')
    end
  end
end
