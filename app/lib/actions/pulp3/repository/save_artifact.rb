module Actions
  module Pulp3
    module Repository
      class SaveArtifact < Pulp3::AbstractAsyncTask
        def plan(file, repository, smart_proxy, tasks, unit_type_id, options = {})
          options[:file_name] = file[:filename]
          options[:sha256] = file[:sha256] || Digest::SHA256.hexdigest(File.read(file[:path]))
          plan_self(:repository_id => repository.id, :smart_proxy_id => smart_proxy.id, :tasks => tasks, :unit_type_id => unit_type_id, :options => options)
        end

        def invoke_external_task
          repository = ::Katello::Repository.find(input[:repository_id])
          artifact_href = input[:options][:artifact_href] || fetch_artifact_href
          fail _("Content not uploaded to pulp") unless artifact_href
          content_type = input[:unit_type_id]
          content_backend_service = SmartProxy.pulp_primary.content_service(content_type)

          existing_content = ::Katello::Pulp3::PulpContentUnit.find_duplicate_unit(repository, input['unit_type_id'], {filename: input[:options][:file_name]}, input[:options][:sha256])
          existing_content_href = existing_content&.results&.first&.pulp_href

          if existing_content_href
            output[:content_unit_href] = existing_content_href
            []
          else
            output[:pulp_tasks] = [content_backend_service.content_api_create(relative_path: input[:options][:file_name],
                                                                              artifact: artifact_href,
                                                                              repository_id: input[:repository_id],
                                                                              content_type: content_type)]
          end
        end

        def fetch_artifact_href
          sha_artifact_list = ::Katello::Pulp3::Api::Core.new(smart_proxy).artifacts_api.list("sha256": input[:options][:sha256])
          sha_artifact_list&.results&.first&.pulp_href
        end
      end
    end
  end
end
