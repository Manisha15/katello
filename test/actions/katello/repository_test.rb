require 'katello_test_helper'

class Dynflow::Testing::DummyPlannedAction
  attr_accessor :error
end

class Dynflow::Testing::DummyExecutionPlan
  attr_accessor :error

  def run_steps
    []
  end
end

module ::Actions::Katello::Repository
  class TestBase < ActiveSupport::TestCase
    include Dynflow::Testing
    include Support::Actions::Fixtures
    include FactoryBot::Syntax::Methods

    let(:action) { create_action action_class }
    let(:repository) { katello_repositories(:rhel_6_x86_64) }
    let(:repository_pulp3) { katello_repositories(:pulp3_file_1) }
    let(:repository_python_pulp3) { katello_repositories(:pulp3_python_1) }
    let(:repository_ansible_collection_pulp3) { katello_repositories(:pulp3_ansible_collection_1) }
    let(:repository_apt_pulp3) { katello_repositories(:pulp3_deb_1) }
    let(:custom_repository) { katello_repositories(:fedora_17_x86_64) }
    let(:deb_repository) { katello_repositories(:debian_10_amd64) }
    let(:docker_repository) { katello_repositories(:redis) }
    let(:proxy) { SmartProxy.pulp_primary }
    let(:capsule_content) { ::Katello::Pulp::SmartProxyRepository.new(proxy) }

    before(:all) do
      set_user
      ::Katello::Product.any_instance.stubs(:certificate).returns(nil)
      ::Katello::Product.any_instance.stubs(:key).returns(nil)
    end
  end

  class UpdateHttpProxyTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::UpdateHttpProxyDetails }

    it 'plans' do
      plan_action action, repository
      assert_action_planned_with action,
        ::Actions::Pulp3::Repository::UpdateRemote,
        repository, proxy
    end
  end

  class CreateTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::Create }
    let(:candlepin_action_class) { ::Actions::Candlepin::Environment::AddContentToEnvironment }

    before do
      repository.expects(:save!)
      action.expects(:action_subject).with(repository)
      action.execution_plan.stub_planned_action(::Actions::Katello::Product::ContentCreate) do |content_create|
        content_create.stubs(input: { content_id: 123 })
      end
    end

    it 'plans' do
      plan_action action, repository
      assert_action_planed_with action, candlepin_action_class, view_env_cp_id: "1", content_id: "69"
    end

    it 'no clone flag means generate metadata in run phase' do
      repository.root.update_attribute(:unprotected, true)
      plan = plan_action action, repository
      run_action plan
      assert_equal 'Actions::Katello::Repository::MetadataGenerate', plan.run.label
    end

    it 'clone flag disables metadata generation' do
      repository.root.update_attribute(:unprotected, true)
      plan = plan_action action, repository, clone: true
      run_action plan
      assert_nil plan.run
      refute_action_planed action, candlepin_action_class
    end
  end

  class CreateFailTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::Create }
    before do
      Dynflow::Testing::DummyPlannedAction.any_instance.stubs(:error).returns("ERROR")
    end

    it 'fails to plan' do
      repository.expects(:save!).never
    end
  end

  class UpdateTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::Update }
    let(:candlepin_action_class) { ::Actions::Candlepin::Product::ContentUpdate }
    let(:repository) { katello_repositories(:fedora_17_unpublished) }
    let(:pulp3_action_class) { ::Actions::Pulp3::Orchestration::Repository::Update }
    def setup
      content = FactoryBot.create(:katello_content, cp_content_id: repository.content_id, organization_id: repository.product.organization_id)
      Katello::ProductContent.create!(:content_id => content.id, :product_id => repository.product_id)
      super
    end

    it 'plans' do
      action = create_action action_class
      action.stubs(:action_subject).with(repository)

      plan_action action, repository.root, :unprotected => true
      assert_action_planed action, candlepin_action_class
    end
  end

  class DestroyTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::Destroy }
    let(:pulp3_action_class) { ::Actions::Pulp3::Orchestration::Repository::Delete }
    let(:unpublished_repository) { katello_repositories(:fedora_17_unpublished) }
    let(:in_use_repository) { katello_repositories(:fedora_17_no_arch) }
    let(:published_repository) { katello_repositories(:rhel_6_x86_64) }
    let(:published_fedora_repository) { katello_repositories(:fedora_17_x86_64) }

    it 'plans' do
      action = create_action action_class
      action.stubs(:action_subject).with(in_use_repository)
      in_use_repository.stubs(:assert_deletable).returns(true)
      in_use_repository.stubs(:destroyable?).returns(true)
      in_use_repository.stubs(:pulp_scratchpad_checksum_type).returns(nil)
      clone = in_use_repository.build_clone(:environment => katello_environments(:dev), :content_view => katello_content_views(:library_dev_view))
      clone.save!

      action.expects(:plan_self)
      plan_action action, in_use_repository
      assert_action_planed_with action, pulp3_action_class,
        in_use_repository, proxy

      refute_action_planned action, ::Actions::BulkAction
      refute_action_planed action, ::Actions::Katello::Product::ContentDestroy
    end

    it 'plans when passed in remove_from_content_view_versions: true' do
      action = create_action action_class
      action.stubs(:action_subject).with(in_use_repository)
      in_use_repository.stubs(:assert_deletable).returns(true)
      in_use_repository.stubs(:destroyable?).returns(true)
      in_use_repository.stubs(:pulp_scratchpad_checksum_type).returns(nil)
      clone = in_use_repository.build_clone(:environment => katello_environments(:dev), :content_view => katello_content_views(:library_dev_view))
      clone.save!

      action.expects(:plan_self)
      plan_action action, in_use_repository, remove_from_content_view_versions: true
      assert_action_planned_with action, pulp3_action_class,
        in_use_repository, proxy

      assert_action_planned_with action, ::Actions::BulkAction, ::Actions::Katello::Repository::Destroy, in_use_repository.library_instances_inverse

      refute_action_planned action, ::Actions::Katello::Product::ContentDestroy
    end

    it 'plans when custom and no clones' do
      action = create_action action_class
      action.stubs(:action_subject).with(unpublished_repository)
      action.expects(:plan_self)
      plan_action action, unpublished_repository

      assert_action_planed_with action, ::Actions::Katello::Product::ContentDestroy, unpublished_repository.root
    end

    it 'does not plan content destroy when custom and 1 clone with planned destroy' do
      clones = published_fedora_repository.clones
      clone = clones.first
      clones.where.not(id: clone.id).destroy_all

      action = create_action action_class
      action.stubs(:action_subject).with(clone)
      action.expects(:plan_self)
      plan_action action, clone

      refute_action_planed action, ::Actions::Katello::Product::ContentDestroy
    end

    it 'plan fails if repository is not deletable' do
      action = create_action action_class
      action.stubs(:action_subject).with(published_repository)

      assert_raises(RuntimeError) do
        plan_action action, published_repository
      end
    end
  end

  class DiscoverTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::Discover }
    let(:action_planned) { create_and_plan_action action_class, 'http://', 'yum', nil, nil, '*' }

    it 'plans' do
      assert_run_phase action_planned
    end

    it 'runs' do
      ::Katello::RepoDiscovery.
          expects(:new).
          returns(mock('discovery', run: nil))

      run_action action_planned
    end
  end

  class RemoveContentTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::RemoveContent }
    let(:capsule_generate_action_class) { ::Actions::Katello::Repository::CapsuleSync }

    it 'plans' do
      to_remove = custom_repository.rpms
      uuids = to_remove.map(&:id)
      action.expects(:action_subject).with(custom_repository)
      plan_action action, custom_repository, to_remove

      assert_action_planed_with action, ::Actions::Pulp3::Orchestration::Repository::RemoveUnits,
        custom_repository, proxy,
        contents: uuids, content_unit_type: "rpm"
    end

    it "does run capsule sync for custom repository" do
      action.expects(:action_subject).with(custom_repository)
      plan_action action, custom_repository, custom_repository.rpms

      assert_action_planned_with(action, capsule_generate_action_class, custom_repository)
    end

    it "does not run capsule sync for custom repository" do
      action.expects(:action_subject).with(custom_repository)
      plan_action action, custom_repository, custom_repository.rpms, sync_capsule: false

      refute_action_planned(action, capsule_generate_action_class)
    end
  end

  class RemoveDockerManifestsTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::RemoveContent }
    let(:docker_repo) { katello_repositories(:redis) }
    let(:uuids) { ["abc123", "def123", "ghi123"] }

    it 'plans' do
      uuids.each do |str|
        docker_repo.docker_manifests.create!(:digest => str) do |manifest|
          manifest.pulp_id = str
        end
      end

      action.expects(:action_subject).with(docker_repo)
      plan_action action, docker_repo, docker_repo.docker_manifests

      assert_action_planed_with action,
       Actions::Pulp3::Orchestration::Repository::RemoveUnits,
       docker_repo, proxy,
       contents: docker_repo.docker_manifests.pluck(:id), content_unit_type: "docker_manifest"
    end
  end

  class UploadContentTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::UploadFiles }
    let(:cli_action_class) { ::Actions::Katello::Repository::ImportUpload }

    it 'plans for applicability regen on upload' do
      file = File.join(::Katello::Engine.root, "test", "fixtures", "files", "squirrel-0.3-0.8.noarch.rpm")
      action.expects(:action_subject).with(custom_repository)
      plan_action action, custom_repository, [{:path => file, :filename => 'squirrel-0.3-0.8.noarch.rpm'}]
      assert_action_planed_with action,
                                ::Actions::Katello::Applicability::Repository::Regenerate,
                                :repo_ids => [custom_repository.id]
    end

    it 'plans for applicability regen on upload through cli' do
      action = create_action cli_action_class
      file = File.join(::Katello::Engine.root, "test", "fixtures", "files", "squirrel-0.3-0.8.noarch.rpm")
      action.expects(:action_subject).with(custom_repository)
      plan_action action, custom_repository, [{:path => file, :filename => 'squirrel-0.3-0.8.noarch.rpm'}]
      assert_action_planed_with action,
                                ::Actions::Katello::Applicability::Repository::Regenerate,
                                :repo_ids => [custom_repository.id]
    end
  end

  class UploadFilesTest < TestBase
    let(:pulp2_action_class) { ::Actions::Pulp::Orchestration::Repository::UploadContent }
    let(:pulp3_action_class) { ::Actions::Pulp3::Orchestration::Repository::UploadContent }

    it 'plans for Pulp3 without duplicate' do
      SmartProxy.any_instance.stubs(:content_service).returns(stub(:content_api => stub(:list => stub(:results => nil))))
      ::Katello::Pulp3::Api::Core.any_instance.stubs(:artifacts_api).returns(stub(:list => stub(:results => nil)))
      action = create_action pulp3_action_class
      file = File.join(::Katello::Engine.root, "test", "fixtures", "files", "puppet_module.tar.gz")
      action.execution_plan.stub_planned_action(::Actions::Pulp3::Repository::UploadFile) do |content_create|
        content_create.stubs(output: { pulp_tasks: [{href: "demo_task/href"}] })
      end
      action.execution_plan.stub_planned_action(::Actions::Pulp3::Repository::SaveArtifact) do |save_artifact|
        save_artifact.stubs(output: { pulp_tasks: [{href: "demo_task/artifact_href"}] })
      end
      action.execution_plan.stub_planned_action(::Actions::Pulp3::Repository::ImportUpload) do |import_upload|
        import_upload.stubs(output: { pulp_tasks: [{href: "demo_task/version_href"}] })
      end

      plan_action action, repository_pulp3, proxy, {:path => file, :filename => 'puppet_module.tar.gz'}, 'file'
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::UploadFile,
                                repository_pulp3, proxy, file)
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::SaveArtifact,
                                {:path => file, :filename => 'puppet_module.tar.gz'},
                                repository_pulp3, proxy,
                                [{href: "demo_task/href"}],
                                "file")
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::ImportUpload,
                                {pulp_tasks: [{href: "demo_task/artifact_href"}]}, repository_pulp3, proxy)
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::SaveVersion,
                                repository_pulp3,
                                tasks: [{href: "demo_task/version_href"}])
    end

    it 'plans for Pulp3 with duplicate' do
      SmartProxy.any_instance.stubs(:content_service).returns(stub(:content_api => stub(:list => stub(:results => [stub(:pulp_href => "demo_content/href")]))))
      action = create_action pulp3_action_class
      file = File.join(::Katello::Engine.root, "test", "fixtures", "files", "puppet_module.tar.gz")
      action.execution_plan.stub_planned_action(::Actions::Pulp3::Repository::ImportUpload) do |import_upload|
        import_upload.stubs(output: { pulp_tasks: [{href: "demo_task/version_href"}] })
      end

      plan_action action, repository_pulp3, proxy, {:path => file, :filename => 'puppet_module.tar.gz'}, 'file'
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::ImportUpload,
                                {content_unit_href: "demo_content/href"}, repository_pulp3, proxy)
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::SaveVersion,
                                repository_pulp3,
                                tasks: [{href: "demo_task/version_href"}])
    end
  end

  class UploadPythonTest < TestBase
    let(:pulp3_action_class) { ::Actions::Pulp3::Orchestration::Repository::UploadContent }

    it 'plans for Pulp3 without duplicate' do
      SmartProxy.any_instance.stubs(:content_service).returns(stub(:content_api => stub(:list => stub(:results => nil))))
      ::Katello::Pulp3::Api::Core.any_instance.stubs(:artifacts_api).returns(stub(:list => stub(:results => nil)))
      action = create_action pulp3_action_class
      file = File.join(::Katello::Engine.root, "test", "fixtures", "files", "shelf_reader-0.1-py2-none-any.whl")
      action.execution_plan.stub_planned_action(::Actions::Pulp3::Repository::UploadFile) do |content_create|
        content_create.stubs(output: { pulp_tasks: [{href: "demo_task/href"}] })
      end
      action.execution_plan.stub_planned_action(::Actions::Pulp3::Repository::SaveArtifact) do |save_artifact|
        save_artifact.stubs(output: { pulp_tasks: [{href: "demo_task/artifact_href"}] })
      end
      action.execution_plan.stub_planned_action(::Actions::Pulp3::Repository::ImportUpload) do |import_upload|
        import_upload.stubs(output: { pulp_tasks: [{href: "demo_task/version_href"}] })
      end

      plan_action action, repository_python_pulp3, proxy, {:path => file, :filename => 'shelf_reader-0.1-py2-none-any.whl'}, 'python_package'
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::UploadFile,
                                repository_python_pulp3, proxy, file)
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::SaveArtifact,
                                {:path => file, :filename => 'shelf_reader-0.1-py2-none-any.whl'},
                                repository_python_pulp3, proxy,
                                [{href: "demo_task/href"}],
                                "python_package")
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::ImportUpload,
                                {pulp_tasks: [{href: "demo_task/artifact_href"}]}, repository_python_pulp3, proxy)
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::SaveVersion,
                                repository_python_pulp3,
                                tasks: [{href: "demo_task/version_href"}])
    end

    it 'plans for Pulp3 with duplicate' do
      SmartProxy.any_instance.stubs(:content_service).returns(stub(:content_api => stub(:list => stub(:results => [stub(:pulp_href => "demo_content/href")]))))
      action = create_action pulp3_action_class
      file = File.join(::Katello::Engine.root, "test", "fixtures", "files", "shelf_reader-0.1-py2-none-any.whl")
      action.execution_plan.stub_planned_action(::Actions::Pulp3::Repository::ImportUpload) do |import_upload|
        import_upload.stubs(output: { pulp_tasks: [{href: "demo_task/version_href"}] })
      end

      plan_action action, repository_python_pulp3, proxy, {:path => file, :filename => 'shelf_reader-0.1-py2-none-any.whl'}, 'python_package'
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::ImportUpload,
                                {content_unit_href: "demo_content/href"}, repository_python_pulp3, proxy)
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::SaveVersion,
                                repository_python_pulp3,
                                tasks: [{href: "demo_task/version_href"}])
    end
  end

  class UploadDockerTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::ImportUpload }
    setup { SmartProxy.stubs(:pulp_primary).returns(SmartProxy.new) }
    it 'plans' do
      action.expects(:action_subject).with(docker_repository)

      uploads = [{'id' => 1, 'size' => '12333', 'checksum' => 'asf23421324', 'name' => 'test'}]

      plan_action action, docker_repository, uploads,
              generate_metadata: true, sync_capsule: true

      import_upload_args = {
        pulp_id: docker_repository.pulp_id,
        unit_type_id: 'docker_manifest',
        unit_key: {'size' => '12333', 'checksum' => 'asf23421324', 'name' => 'test'},
        upload_id: 1,
        unit_metadata: nil
      }
      assert_action_planned_with(action, ::Actions::Pulp3::Orchestration::Repository::ImportUpload,
                                 docker_repository, SmartProxy.pulp_primary,
                                 import_upload_args
                                )
    end

    it 'plans' do
      action.expects(:action_subject).with(docker_repository)

      uploads = [{'id' => 1, 'size' => '12333', 'checksum' => 'asf23421324', 'name' => 'test', 'digest' => 'sha256:1234'}]

      unit_keys = uploads.map { |u| u.except('id') }

      plan_action action, docker_repository, uploads,
              generate_metadata: true, sync_capsule: true, content_type: 'docker_tag'

      import_upload_args = {
        pulp_id: docker_repository.pulp_id,
        unit_type_id: 'docker_tag',
        unit_key: unit_keys[0],
        upload_id: 1,
        unit_metadata: unit_keys[0]
      }
      assert_action_planned_with(action, ::Actions::Pulp3::Orchestration::Repository::ImportUpload,
                                 docker_repository, SmartProxy.pulp_primary,
                                 import_upload_args
                                )
    end
  end

  class FinishUploadTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::FinishUpload }

    it 'plans' do
      plan_action action, custom_repository, :content_type => 'rpm'
      assert_action_planed(action, ::Actions::Katello::Repository::MetadataGenerate)
    end
  end

  class SyncTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::Sync }
    let(:pulp3_action_class) { ::Actions::Pulp3::Orchestration::Repository::Sync }
    let(:pulp3_metadata_generate_action_class) { ::Actions::Pulp3::Orchestration::Repository::GenerateMetadata }

    it 'skips applicability if non-yum and non-deb' do
      action = create_action action_class
      docker_repository.root.url = 'http://foo.com/foo'
      action.stubs(:action_subject).with(docker_repository)
      plan_action action, docker_repository

      refute_action_planed action, ::Actions::Pulp::Repository::RegenerateApplicability
    end

    it 'plans verift checksum when validate_contents is passed' do
      action = create_action action_class
      action.stubs(:action_subject).with(repository)
      plan_action action, repository, :validate_contents => true

      assert_action_planed_with(action, ::Actions::Katello::Repository::VerifyChecksum, repository)
    end

    it 'plans pulp3 orchestration actions with file repo' do
      action = create_action pulp3_action_class
      action.stubs(:action_subject).with(repository_pulp3)
      plan_action action, repository_pulp3, proxy, {}
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::Sync, repository_pulp3, proxy, {})
      assert_action_planed action, ::Actions::Pulp3::Repository::SaveVersion
      assert_action_planed action, ::Actions::Pulp3::Orchestration::Repository::GenerateMetadata
    end

    it 'plans pulp3 metadata generate with contents_changed' do
      action = create_action pulp3_metadata_generate_action_class
      action.stubs(:action_subject).with(repository_pulp3)
      plan_action action, repository_pulp3, proxy, :contents_changed => true
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::CreatePublication, repository_pulp3, proxy, :contents_changed => true)
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::RefreshDistribution, repository_pulp3, proxy, :contents_changed => true)
    end

    it 'plans pulp3 orchestration actions with apt repo' do
      action = create_action pulp3_action_class
      action.stubs(:action_subject).with(repository_apt_pulp3)
      plan_action action, repository_apt_pulp3, proxy, {}
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::Sync, repository_apt_pulp3, proxy, {})
      assert_action_planed action, ::Actions::Pulp3::Repository::SaveVersion
      assert_action_planed action, ::Actions::Pulp3::Orchestration::Repository::GenerateMetadata
    end

    it 'plans pulp3 apt metadata generate with contents_changed' do
      action = create_action pulp3_metadata_generate_action_class
      action.stubs(:action_subject).with(repository_apt_pulp3)
      plan_action action, repository_apt_pulp3, proxy, :contents_changed => true
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::CreatePublication, repository_apt_pulp3, proxy, :contents_changed => true)
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::RefreshDistribution, repository_apt_pulp3, proxy, :contents_changed => true)
    end

    it 'plans pulp3 ansible collection metadata generate without publication ' do
      action = create_action pulp3_metadata_generate_action_class
      action.stubs(:action_subject).with(repository_ansible_collection_pulp3)
      plan_action action, repository_ansible_collection_pulp3, proxy, :contents_changed => true
      refute_action_planed action, ::Actions::Pulp3::Repository::CreatePublication
      assert_action_planed_with(action, ::Actions::Pulp3::Repository::RefreshDistribution, repository_ansible_collection_pulp3, proxy, :contents_changed => true)
    end

    describe 'progress' do
      let(:pulp_action_class) { ::Actions::Pulp::Repository::Sync }
      let(:pulp_action) { fixture_action(pulp_action_class, input: {repo_id: repository.id}, output: fixture_variant) }
      let :action do
        create_action(action_class).tap do |action|
          action.stubs(all_planned_actions: [pulp_action])
        end
      end

      describe 'successfully synchronized' do
        let(:fixture_variant) { :success }

        specify do
          assert_equal 'New packages: 32 (76.7 KB).', action.humanized_output
        end
      end

      describe 'successfully synchronized without new packages' do
        let(:fixture_variant) { :success_no_packages }

        specify do
          assert_equal 'No new packages.', action.humanized_output
        end
      end

      describe 'syncing packages in progress' do
        let(:fixture_variant) { :progress_packages }

        specify do
          assert_equal 'New packages: 20/32 (48 KB/76.7 KB).', action.humanized_output
        end

        specify do
          pulp_action.run_progress.must_be_within_delta 0.6256
        end
      end

      describe 'downloading metadata in progress' do
        let(:fixture_variant) { :progress_metadata }

        specify do
          assert_equal 'Processing metadata', action.humanized_output
        end
      end
    end

    describe 'pulp3 progress' do
      let(:pulp3_action_class) { ::Actions::Pulp3::Repository::Sync }
      let(:pulp3_action) { fixture_action(pulp3_action_class, input: {repo_id: repository.id, smart_proxy_id: SmartProxy.first.id}, output: fixture_variant) }
      let :action do
        create_action(action_class).tap do |action|
          action.stubs(all_planned_actions: [pulp3_action])
        end
      end

      describe 'successfully synchronized pulp3 file' do
        let(:fixture_variant) { :success_file }

        specify do
          assert_equal action.humanized_output, "Total steps: 5/5\n"\
                                             "--------------------------------\n"\
                                             "Associating Content: 1/1\n"\
                                             "Downloading Artifacts: 0/0\n"\
                                             "Downloading Metadata: 1/1\n"\
                                             "Parsing Metadata Lines: 3/3"
        end

        specify do
          pulp3_action.run_progress.must_be_within_delta 1
        end
      end

      describe 'successfully synchronized pulp3 ansible collection' do
        let(:fixture_variant) { :success_ansible_collection }

        specify do
          assert_equal action.humanized_output, "Total steps: 2/2\n"\
                                             "--------------------------------\n"\
                                             "Downloading Collections: 1/1\n"\
                                             "Importing Collections: 1/1"
        end

        specify do
          pulp3_action.run_progress.must_be_within_delta 1
        end
      end

      describe 'successfully synchronized pulp3 docker repo' do
        let(:fixture_variant) { :success_docker }

        specify do
          assert_equal action.humanized_output, "Total steps: 1192/1192\n"\
                                             "--------------------------------\n"\
                                             "Associating Content: 641/641\n"\
                                             "Downloading Artifacts: 415/415\n"\
                                             "Downloading tag list: 1/1\n"\
                                             "Processing Tags: 135/135"
        end

        specify do
          pulp3_action.run_progress.must_be_within_delta 1
        end
      end

      describe 'successfully synchronized pulp3 apt repo' do
        let(:fixture_variant) { :success_apt }

        specify do
          assert_equal action.humanized_output, "Total steps: 93/93\n"\
                                             "--------------------------------\n"\
                                             "Associating Content: 67/67\n"\
                                             "Downloading Artifacts: 16/16\n"\
                                             "Un-Associating Content: 7/7\n"\
                                             "Update PackageIndex units: 2/2\n"\
                                             "Update ReleaseFile units: 1/1"
        end

        specify do
          pulp3_action.run_progress.must_be_within_delta 1
        end
      end

      describe 'syncing files in progress' do
        let(:fixture_variant) { :progress_units_file }

        specify do
          assert_equal action.humanized_output, "Total steps: 15/30\n"\
                                             "--------------------------------\n"\
                                             "Associating Content: 5/10\n"\
                                             "Downloading Artifacts: 5/10\n"\
                                             "Downloading Metadata: 5/10"\
        end

        specify do
          pulp3_action.run_progress.must_be_within_delta 0.50
        end
      end

      describe 'syncing ansible collections in progress' do
        let(:fixture_variant) { :progress_units_ansible_collection }

        specify do
          assert_equal action.humanized_output, "Total steps: 1/2\n"\
                                             "--------------------------------\n"\
                                             "Downloading Collections: 1/2"
        end

        specify do
          pulp3_action.run_progress.must_be_within_delta 0.5
        end
      end
    end
  end

  class CapsuleSyncTest < TestBase
    include Support::CapsuleSupport

    let(:action_class) { ::Actions::Katello::Repository::CapsuleSync }

    it 'plans' do
      smart_proxy_service_1 = new_capsule_content(:three)
      smart_proxy_service_2 = new_capsule_content(:four)
      smart_proxy_service_1.smart_proxy.add_lifecycle_environment(repository.environment)
      smart_proxy_service_2.smart_proxy.add_lifecycle_environment(repository.environment)

      plan_action(action, repository)
      assert_action_planned_with(action, ::Actions::BulkAction) do |action, proxy_list, options|
        assert_equal ::Actions::Katello::CapsuleContent::Sync, action
        assert_equal 2, proxy_list.length
        assert_include proxy_list, smart_proxy_service_1.smart_proxy
        assert_include proxy_list, smart_proxy_service_2.smart_proxy
        assert_equal repository.id, options[:repository_id]
      end
    end
  end

  class CloneContentsFinalizeTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::CloneContents }

    it 'plans' do
      custom_repository.saved_checksum_type = "sha1"
      repository.saved_checksum_type = "sha256"
      planned_action = plan_action action, [repository], custom_repository, :copy_contents => false

      assert_equal planned_action.execution_plan.planned_finalize_steps.first.class, ::Actions::Katello::Repository::CloneContents
      assert_equal planned_action.execution_plan.planned_finalize_steps.first.input, "source_checksum_type" => "sha256", "target_repo_id" => custom_repository.id
    end
  end
end
