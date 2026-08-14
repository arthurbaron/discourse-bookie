import DiscourseRecommended from "@discourse/lint-configs/eslint";

export default [
  ...DiscourseRecommended,
  {
    rules: {
      // Pure member-ordering preference. Reordering a large controller to
      // satisfy it is churn without benefit, so it is off to keep the linter's
      // output meaningful.
      "sort-class-members/sort-class-members": "off",
      // This plugin deliberately uses window.confirm/alert for its admin
      // actions. Switching to Discourse's dialog service is a worthwhile
      // follow-up, but it is a behavioural change, not a lint fix.
      "no-alert": "off",
    },
  },
];
