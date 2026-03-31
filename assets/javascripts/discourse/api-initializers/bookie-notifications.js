import { apiInitializer } from "discourse/lib/api";
import CustomNotification from "discourse/lib/notification-types/custom";

const BOOKIE_MESSAGES = new Set([
  "bookie_match_won",
  "bookie_match_lost",
  "bookie_new_match",
]);

export default apiInitializer("1.3.0", (api) => {
  if (!api.registerNotificationTypeRenderer) {
    return;
  }

  function bookieDescription(message) {
    if (message === "bookie_new_match") {
      return "New events available";
    }

    return "Bets settled";
  }

  api.registerNotificationTypeRenderer("custom", () => {
    return class extends CustomNotification {
      get isBookieNotification() {
        return BOOKIE_MESSAGES.has(this.notification.data.message);
      }

      get linkHref() {
        if (this.isBookieNotification && this.notification.data.link) {
          return this.notification.data.link;
        }

        return super.linkHref;
      }

      get linkTitle() {
        if (this.isBookieNotification) {
          return "Bookie notification";
        }

        return super.linkTitle;
      }

      get icon() {
        if (!this.isBookieNotification) {
          return super.icon;
        }

        return "trophy";
      }

      get label() {
        if (!this.isBookieNotification) {
          return super.label;
        }

        return "Bookie";
      }

      get description() {
        if (!this.isBookieNotification) {
          return super.description;
        }

        return bookieDescription(this.notification.data.message);
      }
    };
  });
});
