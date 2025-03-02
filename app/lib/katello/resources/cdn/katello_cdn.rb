module Katello
  module Resources
    module CDN
      class KatelloCdn < CdnResource
        def initialize(url, options)
          @organization_label = options.delete(:organization_label)
          fail ArgumentError, "No upstream organization was specified" if @organization_label.nil?

          super
        end

        def fetch_paths(content_path)
          url = "/katello/api/v2/repository_sets?organization_id=#{organization['id']}&search=#{CGI.escape("path = #{content_path}")}"
          response = get(url)
          repo_set = JSON.parse(response)['results'].first

          fail _("Upstream organization %s does not provide this content path") % @organization_label if repo_set.nil?

          # now get available repositories when we know the upstream repo set ID
          url = "/katello/api/v2/repository_sets/#{repo_set['id']}/available_repositories?organization_id=#{organization['id']}"
          response = get(url)
          json_body = JSON.parse(response)
          results = json_body['results']

          results.map do |r|
            {
              path: r['path'],
              substitutions: r['substitutions']
            }
          end
        end

        def valid_path?(_path, _postfix)
          true
        end

        def debug_certificate
          get("/katello/api/v2/organizations/#{organization['id']}/download_debug_certificate")
        end

        def repository_url(content_label:)
          response = get("/katello/api/v2/organizations/#{organization['id']}/repositories?search=#{CGI.escape("content_label = #{content_label}")}")
          repository = JSON.parse(response)['results'].first

          if repository.nil?
            fail _("Repository with content label %{content_label} was not found in upstream organization %{org_label}") % { content_label: content_label, org_label: @organization_label }
          end

          repository['full_path']
        end

        private

        def organization
          @organization ||= find_organization(@organization_label)
        end

        def find_organization(label)
          response = get("/api/v2/organizations?search=#{CGI.escape("label = #{label}")}")
          JSON.parse(response)['results'].first
        rescue => e
          Rails.logger.error("Couldn't load upstream organization with label=#{label} error=#{e.message}")
          raise e
        end
      end
    end
  end
end
