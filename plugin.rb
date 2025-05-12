# name: discourse-category-private-writer
# about: Restricts users in configured categories to see only their own topics, while admins see all.
# version: 0.6
# authors: Vinay Kumar

enabled_site_setting :category_private_writer_enabled

after_initialize do
  require_dependency 'topic_query'
  require_dependency 'topic_list'

  module ::CategoryPrivateWriter
    def self.category_configs
      JSON.parse(SiteSetting.category_private_writer_json.presence || "[]")
    rescue JSON::ParserError => e
      Rails.logger.error("CategoryPrivateWriter JSON Parse Error: #{e.message}")
      []
    end

    def self.category_config_for(category_id)
      category_configs.find { |cfg| cfg["category_id"] == category_id }
    end
  end

  class ::TopicQuery
    alias_method :original_list_latest, :list_latest

    def list_latest(options = {})
      result = original_list_latest(options)

      if SiteSetting.category_private_writer_enabled && scope_user&.id && !scope_user.staff?
        result = filter_private_writer_topics(result)
      end

      result
    rescue => e
      Rails.logger.error("CategoryPrivateWriter TopicQuery Error: #{e.message}")
      result
    end

    private

    def filter_private_writer_topics(result)
      user_group_names = (scope_user&.groups&.pluck(:name) || [])

      result.topics = result.topics.select do |topic|
        cfg = ::CategoryPrivateWriter.category_config_for(topic.category_id)
        next true unless cfg

        if (user_group_names & cfg["admin_groups"]).any?
          true
        elsif (user_group_names & cfg["writer_groups"]).any?
          topic.user_id == scope_user.id
        else
          false
        end
      end

      result
    rescue => e
      Rails.logger.error("CategoryPrivateWriter filter_private_writer_topics Error: #{e.message}")
      result
    end
  end

  require_dependency 'guardian'
  class ::Guardian
    alias_method :original_can_see_topic?, :can_see_topic?

    def can_see_topic?(topic)
      return true if original_can_see_topic?(topic)
      return true if user&.staff?

      if SiteSetting.category_private_writer_enabled && user&.id
        cfg = ::CategoryPrivateWriter.category_config_for(topic.category_id)
        if cfg
          return true if user.id == topic.user_id
          user_group_names = user.groups.pluck(:name) rescue []
          return true if (user_group_names & cfg["admin_groups"]).any?
          return false
        end
      end

      false
    rescue => e
      Rails.logger.error("CategoryPrivateWriter Guardian can_see_topic? Error: #{e.message}")
      false
    end
  end
end
