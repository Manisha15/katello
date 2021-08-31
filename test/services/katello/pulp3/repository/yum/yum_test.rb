require 'katello_test_helper'

module Katello
  module Service
    module Pulp3
      class Repository
        class YumTest < ::ActiveSupport::TestCase
          include RepositorySupport

          def setup
            @repo = katello_repositories(:fedora_17_x86_64)
            @proxy = SmartProxy.pulp_primary
          end

          def test_sles_auth_token_not_included_if_blank
            @repo.root.url = "http://foo.com/bar/"
            service = Katello::Pulp3::Repository::Yum.new(@repo, @proxy)
            assert_equal "http://foo.com/bar/", service.remote_options[:url]
            refute service.remote_options.key?(:sles_auth_token)
          end

          def test_delete_version_zero
            service = Katello::Pulp3::Repository::Yum.new(@repo, @proxy)
            @repo.version_href = '/pulp/api/v3/repositories/rpm/rpm/22c9e84b-f49c-4c70-9b4c-49e8c041220f/versions/0/'
            refute service.delete_version
          end

          def test_delete_version
            PulpRpmClient::RepositoriesRpmVersionsApi.any_instance.expects(:delete).returns({})
            service = Katello::Pulp3::Repository::Yum.new(@repo, @proxy)
            @repo.version_href = '/pulp/api/v3/repositories/rpm/rpm/22c9e84b-f49c-4c70-9b4c-49e8c041220f/versions/1/'
            assert service.delete_version
          end

          def test_common_remote_options
            service = Katello::Pulp3::Repository::Yum.new(@repo, @proxy)
            @repo.root.upstream_username = 'foo'
            @repo.root.upstream_password = 'bar'

            assert_equal 'foo', service.common_remote_options[:username]
            assert_equal 'bar', service.common_remote_options[:password]

            @repo.root.upstream_username = ''
            @repo.root.upstream_password = ''

            refute service.common_remote_options[:username]
            refute service.common_remote_options[:password]
          end

          def test_sles_authentication_token_when_set
            service = Katello::Pulp3::Repository::Yum.new(@repo, @proxy)
            @repo.root.upstream_authentication_token = 'foo'
            @repo.root.url = "http://myrepo.com?sauce=awesome"

            assert_equal "http://myrepo.com?sauce=awesome", service.remote_options[:url]
            assert_equal "foo", service.remote_options[:sles_auth_token]
          end

          def test_non_auth_token_query_parameters_are_preserved
            service = Katello::Pulp3::Repository::Yum.new(@repo, @proxy)
            @repo.root.upstream_authentication_token = ''

            refute service.remote_options[:sles_auth_token]

            @repo.root.upstream_authentication_token = ''
            puts service.remote_options
            refute service.remote_options[:sles_auth_token]
          end
        end

        class YumVcrTest < ::ActiveSupport::TestCase
          include RepositorySupport

          def setup
            @repo = katello_repositories(:fedora_17_x86_64)
            @proxy = SmartProxy.pulp_primary
            @service = Katello::Pulp3::Repository::Yum.new(@repo, @proxy)
          end

          def test_create_remote_with_http_proxy_creds
            @service.stubs(:generate_backend_object_name).returns("#{@repo.name}-test")
            HttpProxy.find_by(name: "myhttpproxy").update(username: 'username', password: 'password')
            @repo.root.update(http_proxy_policy: ::Katello::RootRepository::USE_SELECTED_HTTP_PROXY)
            @repo.root.update(http_proxy: HttpProxy.find_by(name: "myhttpproxy"))

            remote_file_data = @service.api.class.remote_class.new(@service.remote_options)
            remote_response = @service.api.remotes_api.create(remote_file_data)
            @service.delete_remote(remote_response.pulp_href)
          end
        end
      end
    end
  end
end
