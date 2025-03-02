require 'katello_test_helper'

module ::Actions::Pulp3
  class YumSyncTest < ActiveSupport::TestCase
    include Katello::Pulp3Support

    def setup
      User.current = users(:admin)
      @primary = SmartProxy.pulp_primary
      @repo = katello_repositories(:fedora_17_x86_64_duplicate)
      @repo.root.update!(url: 'https://jlsherrill.fedorapeople.org/fake-repos/needed-errata/')
      create_repo(@repo, @primary)
      ForemanTasks.sync_task(
          ::Actions::Katello::Repository::MetadataGenerate, @repo)

      repository_reference = Katello::Pulp3::RepositoryReference.find_by(
          :root_repository_id => @repo.root.id,
          :content_view_id => @repo.content_view.id)

      assert repository_reference
      refute_empty repository_reference.repository_href
      refute_empty Katello::Pulp3::DistributionReference.where(repository_id: @repo.id)
      @repo_version_href = @repo.version_href
    end

    def teardown
      User.current = users(:admin)
      ForemanTasks.sync_task(
          ::Actions::Pulp3::Orchestration::Repository::Delete, @repo, @primary)
      @repo.reload
    end

    def test_sync
      sync_args = {:smart_proxy_id => @primary.id, :repo_id => @repo.id}
      @repo.update(publication_href: nil, version_href: nil) #validate that sync populates these
      ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::Sync, @repo, @primary, sync_args)
      @repo.reload
      refute_equal @repo.version_href, @repo_version_href
      repository_reference = Katello::Pulp3::RepositoryReference.find_by(
          :root_repository_id => @repo.root.id,
          :content_view_id => @repo.content_view.id)

      assert_equal repository_reference.repository_href + "versions/1/", @repo.version_href
      refute_nil @repo.version_href
      refute_nil @repo.publication_href
    end

    def test_sync_mirror_false
      sync_args = {:smart_proxy_id => @primary.id, :repo_id => @repo.id}
      @repo.root.update(mirror_on_sync: false)
      @repo.update(publication_href: nil, version_href: nil) #validate that sync populates these
      ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::Sync, @repo, @primary, sync_args)
      @repo.reload
      refute_equal @repo.version_href, @repo_version_href
      repository_reference = Katello::Pulp3::RepositoryReference.find_by(
          :root_repository_id => @repo.root.id,
          :content_view_id => @repo.content_view.id)

      assert_equal repository_reference.repository_href + "versions/1/", @repo.version_href
      refute_nil @repo.version_href
      refute_nil @repo.publication_href
    end

    def test_optimize_false
      SETTINGS[:katello][:katello_applicability] = true
      sync_args = {:smart_proxy_id => @primary.id, :repo_id => @repo.id}
      ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::Sync, @repo, @primary, sync_args)
      @repo.reload

      old_url = @repo.version_href
      @repo.update(version_href: old_url.sub('/1/', '/0/'))
      @repo.index_content #should clear out the repo
      assert_empty @repo.rpms

      task = ForemanTasks.sync_task(::Actions::Katello::Repository::Sync, @repo, skip_metadata_check: true)

      @repo.reload
      assert_equal old_url, @repo.version_href
      refute_empty @repo.rpms

      assert_equal "Added Rpms: 32, Errata: 4", task.get_humanized(:humanized_output).split("\n").first
    ensure
      SETTINGS[:katello][:katello_applicability] = false
    end

    def test_index_erratum_href
      sync_args = {:smart_proxy_id => @primary.id, :repo_id => @repo.id}
      ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::Sync, @repo, @primary, sync_args)
      @repo.reload
      @repo.index_content
      @repo.reload
      total_repository_errata = Katello::RepositoryErratum.where(repository_id: @repo.id).count
      assert_equal total_repository_errata, 4
      repository_errata_without_href = Katello::RepositoryErratum.where(repository_id: @repo.id, erratum_pulp3_href: nil).count
      assert_equal repository_errata_without_href, 0
    end

    def test_reindex_outdated_erratum
      sync_args = {:smart_proxy_id => @primary.id, :repo_id => @repo.id}
      ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::Sync, @repo, @primary, sync_args)
      @repo.reload
      @repo.index_content
      @repo.reload
      erratum = @repo.errata.find_by(errata_id: 'RHEA-2012:0055')
      erratum.repository_errata.first.update(erratum_pulp3_href: 'bad_href')
      erratum.update(title: "bad old title!")
      @repo.index_content
      @repo.index_content
      assert_empty erratum.repository_errata.where(erratum_pulp3_href: 'bad_href')
    end

    def test_incompatible_mirror_repo_error
      @repo.root.update!(url: 'https://dl.fedoraproject.org/pub/epel/7/x86_64/')
      @repo.root.update!(mirror_on_sync: true)
      @repo.reload
      sync_args = {:smart_proxy_id => @primary.id, :repo_id => @repo.id}
      assert_raises ForemanTasks::TaskError do
        ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::Sync, @repo, @primary, sync_args)
      end
    end
  end
end
