# name: discourse-category-private-writer
# version: 1.0
# authors: Vinay Kumar
# url: https://github.com/vinay-kumar/discourse-category-private-writer

enabled_site_setting :category_private_writer_enabled

after_initialize do
  # Module to extend Guardian for topic visibility
  module CategoryPrivateWriterGuardian
    def can_see_topic?(topic)
      return super unless SiteSetting.category_private_writer_enabled
      return super unless topic&.category

      # Get private writer categories
      private_writer_category_ids = SiteSetting.category_private_writer_categories.split('|').map(&:to_i)

      # If topic is not in a private writer category, use default permissions
      return super unless private_writer_category_ids.include?(topic.category_id)

      # Staff (admins and moderators) see all topics
      return true if current_user&.admin? || current_user&.moderator?

      # Get writer and admin groups
      writer_group_ids = SiteSetting.category_private_writer_writer_groups.split('|').map(&:to_i)
      admin_group_ids = SiteSetting.category_private_writer_admin_groups.split('|').map(&:to_i)

      # Check if user is in writer or admin groups
      user_group_ids = current_user&.group_ids || []

      # Admins see all topics
      return true if (user_group_ids & admin_group_ids).any?

      # Writers only see their own topics
      if (user_group_ids & writer_group_ids).any?
        return topic.user_id == current_user&.id
      end

      # Non-writers and non-admins cannot see topics in private writer categories
      false
    end

    def can_create_topic?(category)
      return super unless SiteSetting.category_private_writer_enabled
      return super unless category

      # Get private writer categories
      private_writer_category_ids = SiteSetting.category_private_writer_categories.split('|').map(&:to_i)

      # If category is not private writer, use default permissions
      return super unless private_writer_category_ids.include?(category.id)

      # Staff can always create topics
      return true if current_user&.admin? || current_user&.moderator?

      # Writers can create topics in private writer categories
      writer_group_ids = SiteSetting.category_private_writer_writer_groups.split('|').map(&:to_i)
      user_group_ids = current_user&.group_ids || []
      return true if (user_group_ids & writer_group_ids).any?

      # Non-writers cannot create topics in private writer categories
      false
    end
  end

  # Extend Guardian class
  class ::Guardian
    prepend CategoryPrivateWriterGuardian
  end

  # Modify topic query to filter topics for writers
  add_to_class(:topic_query) do
    def list_latest
      query = super
      if SiteSetting.category_private_writer_enabled && @user && !(@user.admin? || @user.moderator?)
        private_writer_category_ids = SiteSetting.category_private_writer_categories.split('|').map(&:to_i)
        writer_group_ids = SiteSetting.category_private_writer_writer_groups.split('|').map(&:to_i)
        admin_group_ids = SiteSetting.category_private_writer_admin_groups.split('|').map(&:to_i)
        user_group_ids = @user.group_ids || []

        if (user_group_ids & writer_group_ids).any? && (user_group_ids & admin_group_ids).empty?
          # Writers only see their own topics in private writer categories
          query = query.where('topics.category_id NOT IN (?) OR (topics.category_id IN (?) AND topics.user_id = ?)',
                             private_writer_category_ids, private_writer_category_ids, @user.id)
        elsif (user_group_ids & admin_group_ids).empty?
          # Non-writers and non-admins cannot see topics in private writer categories
          query = query.where('topics.category_id NOT IN (?)', private_writer_category_ids)
        end
      end
      query
    end
  end
end