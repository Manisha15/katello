module Actions
  module Pulp3
    class AbstractAsyncTask < Pulp3::Abstract
      include Actions::Base::Polling
      include ::Dynflow::Action::Cancellable

      def run(event = nil)
        # do nothing when the action is being skipped
        unless event == Dynflow::Action::Skip
          super
        end
      end

      def humanized_state
        case state
        when :running
          if self.combined_tasks.empty?
            _("initiating Pulp task")
          else
            _("checking Pulp task status")
          end
        when :suspended
          started_task = combined_tasks.find { |task| task&.started? && !task&.done? }&.pulp_data
          if started_task
            name = started_task[:name] || started_task[:description]
            label = get_task_label(name, started_task[:pulp_href])
            _("waiting for Pulp to finish the task %s" % label)
          else
            pending_task = combined_tasks.find { |task| !task&.started? }&.pulp_data
            name = pending_task[:name] || pending_task[:description]
            label = get_task_label(name, pending_task[:pulp_href])
            _("waiting for Pulp to start the task %s" % label) if pending_task
          end
        else
          super
        end
      end

      def done?
        combined_tasks&.all? { |task| task.done? }
      end

      def external_task
        #this must return nil until external_task= is called
        combined_tasks
      end

      def combined_tasks
        return nil if pulp_tasks.nil? || task_groups.nil?
        pulp_tasks + task_groups
      end

      def pulp_tasks
        return nil if output[:pulp_tasks].nil?
        output[:pulp_tasks] = new_or_existing_objects(::Katello::Pulp3::Task, output[:pulp_tasks])
      end

      def task_groups
        return nil if output[:task_groups].nil?
        output[:task_groups] = new_or_existing_objects(::Katello::Pulp3::TaskGroup, output[:task_groups])
      end

      def new_or_existing_objects(object_class, objects)
        objects.map do |object|
          if object.is_a?(object_class)
            object
          else
            object_class.new(smart_proxy, object)
          end
        end
      end

      def cancel!
        cancel
        poll_external_task
        # We suspend the action and the polling will take care of finding
        # out if the cancelling was successful
        suspend unless done?
      end

      def cancel
        pulp_tasks.each { |task| task.cancel }
        task_groups.each { |task_group| task_group.cancel }
      end

      def rescue_external_task(error)
        if error.is_a?(::Katello::Errors::Pulp3Error)
          fail error
        else
          super
        end
      end

      private

      def transform_task_response(response)
        response = [] if response.nil?
        response = [response] unless response.is_a?(Array)
        response = response.map do |task|
          task.as_json
        end
        response
      end

      def check_for_errors
        combined_tasks.each do |task|
          if (message = task.error)
            fail ::Katello::Errors::Pulp3Error, overwrite_pulp_error(message)
          end
        end
      end

      def overwrite_pulp_error(message)
        case message
        when 'This repository uses features which are incompatible with \'mirror\' sync. Please sync without mirroring enabled.'
          'Please disable \'mirror on sync\' because the upstream repository refers to external resources.'
        else
          message
        end
      end

      def external_task=(external_task_data)
        #currently we assume everything coming from invoke_external_task_methods are tasks
        tasks = transform_task_response(external_task_data)
        output[:pulp_tasks] = new_or_existing_objects(::Katello::Pulp3::Task, tasks)

        add_task_groups
        check_for_errors
      end

      def add_task_groups
        output[:task_groups] ||= []
        pulp_tasks.each do |task|
          if task.task_group_href && !tracking_task_group?(task.task_group_href)
            output[:task_groups] << ::Katello::Pulp3::TaskGroup.new_from_href(smart_proxy, task.task_group_href)
          end
        end
      end

      def tracking_task_group?(href)
        task_groups&.any? { |group| group.href == href }
      end

      def poll_external_task
        pulp_tasks.each(&:poll)
        output[:task_groups] = task_groups.each(&:poll) if task_groups
        add_task_groups
        check_for_errors
        pulp_tasks
      end

      def get_task_label(name, href)
        name = name.split('.').last if name
        href = href.split('-').last[0...-1] if href
        label = "%s (ID: %s)" % [name, href]
        label
      end
    end
  end
end
