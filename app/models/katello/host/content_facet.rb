module Katello
  module Host
    class ContentFacet < Katello::Model
      audited :associated_with => :host
      self.table_name = 'katello_content_facets'
      include Facets::Base

      HOST_TOOLS_PACKAGE_NAME = 'katello-host-tools'.freeze
      HOST_TOOLS_TRACER_PACKAGE_NAME = 'katello-host-tools-tracer'.freeze
      SUBSCRIPTION_MANAGER_PACKAGE_NAME = 'subscription-manager'.freeze

      belongs_to :kickstart_repository, :class_name => "::Katello::Repository", :foreign_key => :kickstart_repository_id, :inverse_of => :kickstart_content_facets
      belongs_to :content_view, :inverse_of => :content_facets, :class_name => "Katello::ContentView"
      belongs_to :lifecycle_environment, :inverse_of => :content_facets, :class_name => "Katello::KTEnvironment"
      belongs_to :content_source, :class_name => "::SmartProxy", :foreign_key => :content_source_id, :inverse_of => :content_facets

      has_many :content_facet_errata, :class_name => "Katello::ContentFacetErratum", :dependent => :delete_all, :inverse_of => :content_facet
      has_many :applicable_errata, :through => :content_facet_errata, :class_name => "Katello::Erratum", :source => :erratum

      has_many :content_facet_repositories, :class_name => "Katello::ContentFacetRepository", :dependent => :destroy, :inverse_of => :content_facet
      has_many :bound_repositories, :through => :content_facet_repositories, :class_name => "Katello::Repository", :source => :repository

      has_many :content_facet_applicable_debs, :class_name => "Katello::ContentFacetApplicableDeb", :dependent => :delete_all, :inverse_of => :content_facet
      has_many :applicable_debs, :through => :content_facet_applicable_debs, :class_name => "Katello::Deb", :source => :deb

      has_many :content_facet_applicable_rpms, :class_name => "Katello::ContentFacetApplicableRpm", :dependent => :delete_all, :inverse_of => :content_facet
      has_many :applicable_rpms, :through => :content_facet_applicable_rpms, :class_name => "Katello::Rpm", :source => :rpm

      has_many :content_facet_applicable_module_streams, :class_name => "Katello::ContentFacetApplicableModuleStream", :dependent => :delete_all, :inverse_of => :content_facet
      has_many :applicable_module_streams, :through => :content_facet_applicable_module_streams, :class_name => "Katello::ModuleStream", :source => :module_stream

      validates :content_view, :presence => true, :allow_blank => false
      validates :lifecycle_environment, :presence => true, :allow_blank => false
      validates_with ::AssociationExistsValidator, attributes: [:content_source]
      validates :host, :presence => true, :allow_blank => false
      validates_with Validators::ContentViewEnvironmentValidator

      def update_repositories_by_paths(paths)
        prefixes = %w(/pulp/deb/ /pulp/repos/ /pulp/content/)
        relative_paths = []

        # paths == ["/pulp/content/Default_Organization/Library/custom/Test_product/test2"]
        paths.each do |path|
          if (prefix = prefixes.find { |pre| path.start_with?(pre) })
            relative_paths << path.gsub(prefix, '')
          else
            Rails.logger.warn("System #{self.host.name} (#{self.host.id}) requested binding to repo with unknown prefix. #{path}")
          end
        end

        repos = Repository.where(relative_path: relative_paths)
        relative_paths -= repos.pluck(:relative_path) # remove relative paths that match our repos

        # Any leftover relative paths do not match the repos we've just retrieved from the db,
        # so we should log warnings about them.
        relative_paths.each do |repo_path|
          Rails.logger.warn("System #{self.host.name} (#{self.host.id}) requested binding to unknown repo #{repo_path}")
        end

        unless self.bound_repositories.sort == repos.sort
          self.bound_repositories = repos
          self.save!
        end
        self.bound_repositories.pluck(:relative_path)
      end

      def installable_errata(env = nil, content_view = nil)
        Erratum.installable_for_content_facet(self, env, content_view)
      end

      def installable_debs(env = nil, content_view = nil)
        Deb.installable_for_content_facet(self, env, content_view)
      end

      def installable_rpms(env = nil, content_view = nil)
        Rpm.installable_for_content_facet(self, env, content_view)
      end

      def installable_module_streams(env = nil, content_view = nil)
        ModuleStream.installable_for_content_facet(self, env, content_view)
      end

      def errata_counts
        hash = {
          :security => installable_security_errata_count,
          :bugfix => installable_bugfix_errata_count,
          :enhancement => installable_enhancement_errata_count
        }
        hash[:total] = hash.values.inject(:+)
        hash
      end

      def self.trigger_applicability_generation(host_ids)
        host_ids = [host_ids] unless host_ids.is_a?(Array)
        ::Katello::ApplicableHostQueue.push_hosts(host_ids)
        ::Katello::EventQueue.push_event(::Katello::Events::GenerateHostApplicability::EVENT_TYPE, 0)
      end

      # Katello applicability
      def calculate_and_import_applicability
        bound_repos = bound_repositories.collect do |repo|
          repo.library_instance_id.nil? ? repo.id : repo.library_instance_id
        end

        ::Katello::Applicability::ApplicableContentHelper.new(self, ::Katello::Deb, bound_repos).calculate_and_import
        ::Katello::Applicability::ApplicableContentHelper.new(self, ::Katello::Rpm, bound_repos).calculate_and_import
        ::Katello::Applicability::ApplicableContentHelper.new(self, ::Katello::Erratum, bound_repos).calculate_and_import
        ::Katello::Applicability::ApplicableContentHelper.new(self, ::Katello::ModuleStream, bound_repos).calculate_and_import
        update_applicability_counts
        self.update_errata_status
      end

      def import_applicability(partial = false)
        import_module_stream_applicability(partial)
        import_errata_applicability(partial)
        import_deb_applicability(partial)
        import_rpm_applicability(partial)
        update_applicability_counts
      end

      def update_applicability_counts
        self.assign_attributes(
            :installable_security_errata_count => self.installable_errata.security.count,
            :installable_bugfix_errata_count => self.installable_errata.bugfix.count,
            :installable_enhancement_errata_count => self.installable_errata.enhancement.count,
            :applicable_deb_count => self.content_facet_applicable_debs.count,
            :upgradable_deb_count => self.installable_debs.count,
            :applicable_rpm_count => self.content_facet_applicable_rpms.count,
            :upgradable_rpm_count => self.installable_rpms.count,
            :applicable_module_stream_count => self.content_facet_applicable_module_streams.count,
            :upgradable_module_stream_count => self.installable_module_streams.count
        )
        self.save!(:validate => false)
      end

      def import_deb_applicability(partial)
        ApplicableContentHelper.new(Deb, self).import(partial)
      end

      def import_rpm_applicability(partial)
        ApplicableContentHelper.new(Rpm, self).import(partial)
      end

      def import_errata_applicability(partial)
        ApplicableContentHelper.new(Erratum, self).import(partial)
        self.update_errata_status
      end

      def import_module_stream_applicability(partial)
        ApplicableContentHelper.new(ModuleStream, self).import(partial)
      end

      def self.in_content_view_version_environments(version_environments)
        #takes a structure of [{:content_view_version => ContentViewVersion, :environments => [KTEnvironment]}]
        queries = version_environments.map do |version_environment|
          version = version_environment[:content_view_version]
          env_ids = version_environment[:environments].map(&:id)
          "(#{table_name}.content_view_id = #{version.content_view_id} AND #{table_name}.lifecycle_environment_id IN (#{env_ids.join(',')}))"
        end
        where(queries.join(" OR "))
      end

      def self.with_non_installable_errata(errata, hosts = nil)
        content_facets = Katello::Host::ContentFacet.select(:id).where(:host_id => hosts)
        reachable_repos = ::Katello::ContentFacetRepository.where(content_facet_id: content_facets).distinct.pluck(:repository_id)
        installable_errata = ::Katello::ContentFacetErratum.select(:id).
          where(content_facet_id: content_facets).
          joins(
          "inner join #{::Katello::RepositoryErratum.table_name} ON #{Katello::ContentFacetErratum.table_name}.erratum_id = #{Katello::RepositoryErratum.table_name}.erratum_id",
          "inner JOIN #{Katello::ContentFacetRepository.table_name} "\
            "ON #{Katello::ContentFacetErratum.table_name}.content_facet_id = #{Katello::ContentFacetRepository.table_name}.content_facet_id "\
            "AND #{Katello::RepositoryErratum.table_name}.repository_id = #{Katello::ContentFacetRepository.table_name}.repository_id"
          ).
          where("#{Katello::RepositoryErratum.table_name}.repository_id" => reachable_repos).
          where("#{Katello::RepositoryErratum.table_name}.erratum_id" => errata).
          where("#{Katello::ContentFacetRepository.table_name}.repository_id" => reachable_repos).
          where("#{Katello::ContentFacetRepository.table_name}.content_facet_id" => content_facets)

        non_installable_errata = ::Katello::ContentFacetErratum.select(:content_facet_id).
          where.not(id: installable_errata).
          where(content_facet_id: content_facets, erratum_id: errata)

        Katello::Host::ContentFacet.where(id: non_installable_errata)
      end

      def self.with_applicable_errata(errata)
        self.joins(:applicable_errata).where("#{Katello::Erratum.table_name}.id" => errata)
      end

      def self.with_installable_errata(errata)
        joins_installable_errata.where("#{Katello::Erratum.table_name}.id" => errata)
      end

      def self.joins_installable_errata
        joins_installable_relation(Katello::Erratum, Katello::ContentFacetErratum)
      end

      def self.joins_installable_debs
        joins_installable_relation(Katello::Deb, Katello::ContentFacetApplicableDeb)
      end

      def self.joins_installable_rpms
        joins_installable_relation(Katello::Rpm, Katello::ContentFacetApplicableRpm)
      end

      def content_view_version
        content_view.version(lifecycle_environment)
      end

      def available_releases
        self.content_view.version(self.lifecycle_environment).available_releases
      end

      def katello_agent_installed?
        self.host.installed_packages.where("#{Katello::InstalledPackage.table_name}.name" => 'katello-agent').any?
      end

      def tracer_installed?
        self.host.installed_packages.where("#{Katello::InstalledPackage.table_name}.name" => [ "python-#{HOST_TOOLS_TRACER_PACKAGE_NAME}",
                                                                                               "python3-#{HOST_TOOLS_TRACER_PACKAGE_NAME}",
                                                                                               HOST_TOOLS_TRACER_PACKAGE_NAME ]).any?
      end

      def host_tools_installed?
        host.installed_packages.where("#{Katello::InstalledPackage.table_name}.name" => [ "python-#{HOST_TOOLS_PACKAGE_NAME}",
                                                                                          "python3-#{HOST_TOOLS_PACKAGE_NAME}",
                                                                                          HOST_TOOLS_PACKAGE_NAME ]).any?
      end

      def update_errata_status
        host.get_status(::Katello::ErrataStatus).refresh!
        host.refresh_global_status!
      end

      def self.joins_installable_relation(content_model, facet_join_model)
        facet_repository = Katello::ContentFacetRepository.table_name
        content_table = content_model.table_name
        facet_join_table = facet_join_model.table_name
        repo_join_table = content_model.repository_association_class.table_name

        self.joins("INNER JOIN #{facet_repository} on #{facet_repository}.content_facet_id = #{table_name}.id",
                   "INNER JOIN #{repo_join_table} on #{repo_join_table}.repository_id = #{facet_repository}.repository_id",
                   "INNER JOIN #{content_table} on #{content_table}.id = #{repo_join_table}.#{content_model.unit_id_field}",
                   "INNER JOIN #{facet_join_table} on #{facet_join_table}.#{content_model.unit_id_field} = #{content_table}.id").
             where("#{facet_join_table}.content_facet_id = #{self.table_name}.id")
      end

      def self.inherited_attributes(hostgroup, facet_attributes)
        facet_attributes[:kickstart_repository_id] ||= hostgroup.inherited_kickstart_repository_id
        facet_attributes[:content_view_id] ||= hostgroup.inherited_content_view_id
        facet_attributes[:lifecycle_environment_id] ||= hostgroup.inherited_lifecycle_environment_id
        facet_attributes[:content_source_id] ||= hostgroup.inherited_content_source_id
        facet_attributes
      end

      apipie :class, desc: "A class representing #{model_name.human} object" do
        name 'Content Facet'
        refs 'ContentFacet'
        sections only: %w[all additional]
        desc "Content facet is an object containing the host's content-related metadata and associations"
        property :id, Integer, desc: 'Returns ID of the facet'
        property :uuid, String, desc: 'Returns UUID of the facet'
        property :applicable_module_stream_count, Integer, desc: 'Returns applicable Module Stream count'
        property :upgradable_module_stream_count, Integer, desc: 'Returns upgradable Module Stream count'
        property :applicable_deb_count, Integer, desc: 'Returns applicable DEB count'
        property :upgradable_deb_count, Integer, desc: 'Returns upgradable DEB count'
        property :applicable_rpm_count, Integer, desc: 'Returns applicable RPM count'
        property :upgradable_rpm_count, Integer, desc: 'Returns upgradable RPM count'
        property :content_source, 'SmartProxy', desc: 'Returns Smart Proxy object as the content source'
        prop_group :katello_idname_props, Katello::Model, meta: { resource: 'content_source' }
        prop_group :katello_idname_props, Katello::Model, meta: { resource: 'content_view' }
        property :errata_counts, Hash, desc: 'Returns key=value object with errata counts, e.g. {security: 0, bugfix: 0, enhancement: 0, total: 0}'
        property :kickstart_repository, 'Repository', desc: 'Returns Kickstart repository object'
        prop_group :katello_idname_props, Katello::Model, meta: { resource: 'kickstart_repository' }
        prop_group :katello_idname_props, Katello::Model, meta: { resource: 'lifecycle_environment' }
      end
      class Jail < ::Safemode::Jail
        allow :applicable_deb_count, :applicable_module_stream_count, :applicable_rpm_count, :content_source, :content_source_id, :content_source_name, :content_view_id,
              :content_view_name, :errata_counts, :id, :kickstart_repository, :kickstart_repository_id, :kickstart_repository_name,
              :lifecycle_environment_id, :lifecycle_environment_name, :upgradable_deb_count, :upgradable_module_stream_count, :upgradable_rpm_count, :uuid
      end
    end
  end
end
