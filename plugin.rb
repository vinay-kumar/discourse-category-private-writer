# name: discourse-category-private-writer
# about: Restricts users in configured categories to see only their own topics, while admins see all.
# version: 0.4
# authors: Your Name

enabled_site_setting :category_private_writer_enabled

after_initialize do
  require_dependency 'topic_query'
  require_dependency 'topic_list'

  module ::CategoryPrivateWriter
    def self.category_configs
      SiteSetting.category_private_writer_configurations
        .split('|')
        .map(&:strip)
        .reject(&:empty?)
        .map do |config|
          category_id_str, writers_str, admins_str = config.split(';').map(&:strip)
          {
            category_id: category_id_str.to_i,
            writer_groups: writers_str&.split(',')&.map(&:strip)&.reject(&:empty?) || [],
            admin_groups: admins_str&.split(',')&.map(&:strip)&.reject(&:empty?) || []
          }
        end
    end

    def self.category_config_for(category_id)
      category_configs.find { |cfg| cfg[:category_id] == category_id }
    end
  end

  class ::TopicQuery
    alias_method :original_list_latest, :list_latest

    def list_latest(options = {})
      result = original_list_latest(options)

      if SiteSetting.category_private_writer_enabled && scope_user && !scope_user.staff?
        result = filter_private_writer_topics(result)
      end

      result
    end

    private

    def filter_private_writer_topics(result)
      user_group_names = scope_user.groups.pluck(:name)

      result.topics = result.topics.select do |topic|
        cfg = ::CategoryPrivateWriter.category_config_for(topic.category_id)
        next true unless cfg

        if (user_group_names & cfg[:admin_groups]).any?
          true
        elsif (user_group_names & cfg[:writer_groups]).any?
          topic.user_id == scope_user.id
        else
          false
        end
      end

      result
    end
  end

  require_dependency 'guardian'
  class ::Guardian
    alias_method :original_can_see_topic?, :can_see_topic?

    def can_see_topic?(topic)
      return true if original_can_see_topic?(topic)
      return true if user&.staff?

      if SiteSetting.category_private_writer_enabled
        cfg = ::CategoryPrivateWriter.category_config_for(topic.category_id)
        if cfg
          return true if user.id == topic.user_id
          return true if (user.groups.pluck(:name) & cfg[:admin_groups]).any?
          return false
        end
      end

      false
    end
  end
end
