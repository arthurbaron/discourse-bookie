class BookieNotifier
  DISPLAY_USERNAME = "Bookie".freeze
  RESULTS_LINK = "/bookie?tab=results".freeze
  MATCHES_LINK = "/bookie?tab=matches".freeze
  NEW_MATCH_COOLDOWN = 5.minutes

  def self.notify_match_settled!(match:, bet:, won:, currency_name:)
    create_custom_notification!(
      user_id: bet.user_id,
      message: won ? "bookie_match_won" : "bookie_match_lost",
      label: DISPLAY_USERNAME,
      description: "Bets settled",
      text: "Bookie — Bets settled",
      link: RESULTS_LINK
    )
  end

  def self.notify_new_match_available!(match:)
    interested_user_ids = BookieBet.distinct.pluck(:user_id)
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
    link:
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
      }.to_json
    )
  end
end
