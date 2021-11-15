require "pulpcore_client"

module Katello
  module Pulp3
    module Api
      class Apt < Core
        def self.copy_class
          PulpDebClient::Copy
        end

        def self.add_remove_content_class
          PulpDebClient::RepositoryAddRemoveContent
        end

        def copy_api
          PulpDebClient::CopyApi.new(api_client)
        end
      end
    end
  end
end
