import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

// Wraps each match with reactive (tracked) state for the bet form.
class MatchState {
  @tracked selectedChoice = null;
  @tracked betAmount = "";
  @tracked betError = null;
  @tracked _userBet = null;
  @tracked _canBet = false;

  constructor(data) {
    Object.assign(this, data);
    this._userBet = data.user_bet || null;
    this._canBet = data.can_bet || false;
  }

  get userBet() {
    return this._userBet;
  }

  get canBet() {
    return this._canBet;
  }

  get calcPayout() {
    if (!this.selectedChoice || !this.betAmount) return 0;
    const odds = parseFloat(this[`odds_${this.selectedChoice}`]) || 1;
    return Math.round(parseInt(this.betAmount, 10) * odds);
  }

  get betDisabled() {
    return !this.selectedChoice || parseInt(this.betAmount, 10) < 10;
  }

  get formattedDeadline() {
    return new Date(this.deadline).toLocaleString("en-GB", {
      weekday: "short",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  get resultText() {
    if (this.result === "home") return `${this.home_team} won`;
    if (this.result === "away") return `${this.away_team} won`;
    if (this.result === "draw") return "Draw";
    return "";
  }

  get userBetLabel() {
    if (!this._userBet) return "";
    const c = this._userBet.choice;
    if (c === "home") return this.home_team;
    if (c === "away") return this.away_team;
    return "Draw";
  }

  get userBetResultClass() {
    if (!this._userBet) return "";
    return `bet-status-${this._userBet.status}`;
  }
}

function formatDate(iso) {
  return new Date(iso).toLocaleString("en-GB", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default class BookieController extends Controller {
  @service currentUser;

  @tracked activeTab = "matches";
  @tracked matches = [];
  @tracked settledMatches = [];
  @tracked balance = 0;
  @tracked currency = "Coins";
  @tracked walletTransactions = [];
  @tracked walletBalance = 0;
  // Standings state
  @tracked standingsTab = "league-table";
  @tracked leagueTable = [];
  @tracked richestGooner = [];
  @tracked currentPeriodLabel = "";
  @tracked prevPeriodLabel = null;
  @tracked prevPeriodTop3 = [];

  // Admin state
  @tracked adminMatches = [];
  @tracked adminError = null;
  @tracked seasonKey = null;
  @tracked seasonAlreadyClosed = false;
  @tracked seasonLoading = false;
  @tracked nmHomeTeam = "";
  @tracked nmAwayTeam = "";
  @tracked nmTitle = "";
  @tracked nmOddsHome = "1.90";
  @tracked nmOddsDraw = "3.50";
  @tracked nmOddsAway = "4.00";
  @tracked nmDeadline = "";

  // Computed podium/rest slices (used by template)
  get leaguePodium() { return this.leagueTable.slice(0, 3); }
  get leagueRest()   { return this.leagueTable.slice(3); }
  get richestPodium() { return this.richestGooner.slice(0, 3); }
  get richestRest()   { return this.richestGooner.slice(3); }

  setup(model) {
    this.matches = (model.matches || []).map((m) => new MatchState(m));
    this.settledMatches = (model.settled_matches || []).map(
      (m) => new MatchState(m)
    );
    this.balance = model.balance || 0;
    this.currency = model.currency || "Coins";
    this.walletBalance = model.wallet?.balance || 0;
    this.walletTransactions = (model.wallet?.transactions || []).map((tx) => ({
      ...tx,
      formattedDate: formatDate(tx.date),
    }));
    const lb = model.leaderboard || {};
    this.leagueTable       = lb.league_table      || [];
    this.richestGooner     = lb.richest_gooner     || [];
    this.currentPeriodLabel = lb.current_period_label || "";
    this.prevPeriodLabel   = lb.prev_period_label  || null;
    this.prevPeriodTop3    = lb.prev_period_top3   || [];
  }

  // ── Tab navigation ──────────────────────────────────

  @action
  setStandingsTab(tab) {
    this.standingsTab = tab;
  }

  @action
  setTab(tab) {
    this.activeTab = tab;
    if (tab === "admin") {
      this.loadAdminMatches();
      this.loadSeasonStatus();
    } else if (tab === "wallet") {
      this.refreshWallet();
    }
  }

  // ── Bet form ────────────────────────────────────────

  @action
  selectChoice(match, choice) {
    match.selectedChoice = match.selectedChoice === choice ? null : choice;
    match.betError = null;
  }

  @action
  setAmount(match, event) {
    match.betAmount = event.target.value;
  }

  @action
  async placeBet(match) {
    const amount = parseInt(match.betAmount, 10);

    if (isNaN(amount) || amount < 10) {
      match.betError = "Minimum bet is 10 coins.";
      return;
    }
    if (amount > this.balance) {
      match.betError = "Insufficient balance.";
      return;
    }

    try {
      const result = await ajax("/bookie/bets.json", {
        type: "POST",
        data: { match_id: match.id, choice: match.selectedChoice, amount },
      });

      this.balance = result.new_balance;
      match._userBet = result.bet;
      match._canBet = false;
      match.selectedChoice = null;
      match.betAmount = "";
      match.betError = null;
    } catch (e) {
      match.betError =
        e.jqXHR?.responseJSON?.error || "Something went wrong. Try again.";
    }
  }

  @action
  async cancelBet(match) {
    if (!confirm("Cancel your bet? The amount will be refunded to your wallet.")) {
      return;
    }

    try {
      await ajax(`/bookie/bets/${match._userBet.id}.json`, { type: "DELETE" });
      this.balance += match._userBet.amount;
      match._userBet = null;
      match._canBet = true;
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Something went wrong.");
    }
  }

  // ── Wallet ──────────────────────────────────────────

  async refreshWallet() {
    try {
      const data = await ajax("/bookie/wallet.json");
      this.walletBalance = data.balance;
      this.walletTransactions = (data.transactions || []).map((tx) => ({
        ...tx,
        formattedDate: formatDate(tx.date),
        isPositive: tx.amount > 0,
      }));
    } catch (_e) {
      // silently fail
    }
  }

  // ── Admin ────────────────────────────────────────────

  @action
  async loadAdminMatches() {
    try {
      const data = await ajax("/admin/plugins/bookie/matches.json");
      this.adminMatches = (data.matches || []).map((m) => ({
        ...m,
        formattedDeadline: formatDate(m.deadline),
      }));
    } catch (_e) {
      this.adminError = "Failed to load matches.";
    }
  }

  @action
  updateField(field, event) {
    this[field] = event.target.value;
  }

  @action
  async createMatch() {
    if (!this.nmHomeTeam || !this.nmAwayTeam || !this.nmDeadline) {
      this.adminError = "Home team, away team and deadline are required.";
      return;
    }

    const title =
      this.nmTitle || `${this.nmHomeTeam} vs ${this.nmAwayTeam}`;

    try {
      const result = await ajax("/admin/plugins/bookie/matches.json", {
        type: "POST",
        data: {
          match: {
            title,
            home_team: this.nmHomeTeam,
            away_team: this.nmAwayTeam,
            odds_home: this.nmOddsHome,
            odds_draw: this.nmOddsDraw,
            odds_away: this.nmOddsAway,
            deadline: this.nmDeadline,
          },
        },
      });

      const m = result.match;
      this.adminMatches = [
        { ...m, formattedDeadline: formatDate(m.deadline) },
        ...this.adminMatches,
      ];

      // Reset form
      this.nmHomeTeam = "";
      this.nmAwayTeam = "";
      this.nmTitle = "";
      this.nmOddsHome = "1.90";
      this.nmOddsDraw = "3.50";
      this.nmOddsAway = "4.00";
      this.nmDeadline = "";
      this.adminError = null;
    } catch (e) {
      const errors = e.jqXHR?.responseJSON?.errors;
      this.adminError = errors ? errors.join(", ") : "Failed to create match.";
    }
  }

  @action
  async settleMatch(match, result) {
    const labels = {
      home: `${match.home_team} wins`,
      draw: "Draw",
      away: `${match.away_team} wins`,
    };
    if (!confirm(`Settle match as: ${labels[result]}?`)) return;

    try {
      await ajax(`/admin/plugins/bookie/matches/${match.id}/settle.json`, {
        type: "POST",
        data: { result },
      });

      this.adminMatches = this.adminMatches.filter((m) => m.id !== match.id);

      // Refresh user-facing data
      const freshData = await ajax("/bookie/matches.json");
      this.balance = freshData.balance;
      this.matches = (freshData.matches || []).map((m) => new MatchState(m));
      this.settledMatches = (freshData.settled_matches || []).map(
        (m) => new MatchState(m)
      );
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Failed to settle match.");
    }
  }

  // ── Season management ────────────────────────────────

  async loadSeasonStatus() {
    try {
      const data = await ajax("/admin/plugins/bookie/season.json");
      this.seasonKey = data.current_season_key;
      this.seasonAlreadyClosed = data.already_closed;
    } catch (_e) {
      // silently fail
    }
  }

  @action
  async endSeason() {
    if (
      !confirm(
        `End season ${this.seasonKey}?\n\n` +
        `This will:\n` +
        `• Save the Richest Gooner top 3 as season winners\n` +
        `• Reset all wallet balances to the starting amount\n\n` +
        `This cannot be undone.`
      )
    ) {
      return;
    }

    this.seasonLoading = true;
    try {
      await ajax("/admin/plugins/bookie/season/end.json", { type: "POST" });
      this.seasonAlreadyClosed = true;
      alert(`Season ${this.seasonKey} closed. All balances have been reset!`);
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Failed to end season.");
    } finally {
      this.seasonLoading = false;
    }
  }

  @action
  async deleteMatch(match) {
    if (
      !confirm(
        `Delete "${match.title}"? All pending bets will be refunded.`
      )
    ) {
      return;
    }

    try {
      await ajax(`/admin/plugins/bookie/matches/${match.id}.json`, {
        type: "DELETE",
      });
      this.adminMatches = this.adminMatches.filter((m) => m.id !== match.id);
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Failed to delete match.");
    }
  }
}
