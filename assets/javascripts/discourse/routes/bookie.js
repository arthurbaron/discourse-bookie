import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class BookieRoute extends DiscourseRoute {
  queryParams = {
    tab: { refreshModel: false },
  };

  async model() {
    const [matchesData, walletData, leaderboardData, accumulatorsData] =
      await Promise.all([
        ajax("/bookie/matches.json"),
        ajax("/bookie/wallet.json"),
        ajax("/bookie/leaderboard.json"),
        ajax("/bookie/accumulators.json"),
      ]);

    return {
      matches: matchesData.matches || [],
      settled_matches: matchesData.settled_matches || [],
      results_stats: matchesData.stats || {},
      balance: matchesData.balance || 0,
      currency: matchesData.currency || "coins",
      wallet: walletData || { transactions: [] },
      leaderboard: leaderboardData || { overall: [], last_month: [] },
      accumulators: accumulatorsData.accumulators || [],
    };
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setup(model);
  }
}
