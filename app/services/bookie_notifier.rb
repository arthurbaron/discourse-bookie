class BookieNotifier
  DISPLAY_USERNAME = "Bookie".freeze
  RESULTS_LINK = "/bookie?tab=results".freeze
  MATCHES_LINK = "/bookie?tab=matches".freeze
  NEW_MATCH_COOLDOWN = 5.minutes
  SETTLED_COOLDOWN = 10.minutes
  ACHIEVEMENT_MESSAGE = "bookie_achievement_unlocked".freeze
  SETTLED_MESSAGE = "bookie_bets_settled".freeze

  def self.notifications_enabled?(user_id)
    user = User.find_by(id: user_id)
    return false unless user
    user.custom_fields["bookie_notifications_enabled"] != "false"
  end

  # One consolidated "Bets settled" notification per affected user, covering
  # both single bets and accumulator legs. A cooldown collapses several
  # settlements in a short window into a single ping. Achievement unlocks are
  # still notified separately (and respect the same on/off preference).
  def self.notify_bets_settled!(user_ids:)
    user_ids.compact.uniq.each do |user_id|
      notify_settled_summary!(user_id)
      notify_achievement_unlocks!(user_id: user_id)
    end
  end

  def self.notify_settled_summary!(user_id)
    return unless notifications_enabled?(user_id)

    recently_notified =
      Notification
        .where(notification_type: Notification.types[:custom], user_id: user_id)
        .where("created_at >= ?", Time.zone.now - SETTLED_COOLDOWN)
        .where("data::json ->> 'message' = ?", SETTLED_MESSAGE)
        .exists?
    return if recently_notified

    create_custom_notification!(
      user_id: user_id,
      message: SETTLED_MESSAGE,
      label: DISPLAY_USERNAME,
      description: "Bets settled",
      text: "Bookie — Bets settled",
      link: RESULTS_LINK
    )
  end

  def self.notify_achievement_unlocks!(user_id:)
    return unless notifications_enabled?(user_id)

    achievements = BookieAchievements.earned_for(user_id)
    return if achievements.empty?

    notified_keys = Notification
      .where(
        notification_type: Notification.types[:custom],
        user_id: user_id
      )
      .where("data::json ->> 'message' = ?", ACHIEVEMENT_MESSAGE)
      .pluck(Arel.sql("data::json ->> 'achievement_key'"))

    achievements.each do |achievement|
      next if notified_keys.include?(achievement[:key])

      create_custom_notification!(
        user_id: user_id,
        message: ACHIEVEMENT_MESSAGE,
        label: DISPLAY_USERNAME,
        description: "Achievement unlocked: #{achievement[:title]}",
        text: "Bookie — Achievement unlocked: #{achievement[:title]}",
        link: RESULTS_LINK,
        extra_data: {
          achievement_key: achievement[:key],
          achievement_title: achievement[:title]
        }
      )
    end
  end

  def self.notify_new_match_available!(match:)
    interested_user_ids = BookieBet.distinct.pluck(:user_id)
    return if interested_user_ids.empty?

    interested_user_ids = interested_user_ids.select { |id| notifications_enabled?(id) }
    return if interested_user_ids.empty?

    recently_notified_user_ids =
      Notification
        .where(
          notification_type: Notification.types[:custom],
          user_id: interested_user_ids
        )
        .where("created_at >= ?", Time.zone.now - NEW_MATCH_COOLDOWN)
        .where("data::json ->> 'message' = ?", "bookie_new_match")
        .distinct
        .pluck(:user_id)

    User
      .where(id: interested_user_ids, active: true)
      .where.not(id: recently_notified_user_ids)
      .where(staged: false)
      .where("suspended_till IS NULL OR suspended_till < ?", Time.zone.now)
      .find_each do |user|
        create_custom_notification!(
          user_id: user.id,
          message: "bookie_new_match",
          label: DISPLAY_USERNAME,
          description: "New events available",
          text: "Bookie — New events available",
          link: MATCHES_LINK
        )
      end
  end

  def self.create_custom_notification!(
    user_id:,
    message:,
    label:,
    description:,
    text:,
    link:,
    extra_data: {}
  )
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: user_id,
      data: {
        message: message,
        label: label,
        description: description,
        text: text,
        link: link,
        display_username: DISPLAY_USERNAME
      }.merge(extra_data).to_json
    )
  end
end
