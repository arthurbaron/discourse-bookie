import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { and, eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import BookieResultsChart from "../components/bookie-results-chart";

export default <template>
  <div class="bookie-page">

    {{! ── Header ── }}
    <div class="bookie-header">
      <div class="bookie-header-title">
        <span class="bookie-header-trophy">🏆</span>
        <h1>Bookie</h1>
      </div>
      <div class="bookie-balance-badge">
        <span class="bookie-balance-label">Your balance</span>
        <span class="bookie-balance-amount">{{@controller.balance}}
          {{@controller.currency}}</span>
      </div>
    </div>

    {{! ── Tabs ── }}
    <div class="bookie-tabs-shell">
      <div class="bookie-tabs">
        <button
          class="bookie-tab
            {{if (eq @controller.activeTab 'matches') 'active'}}"
          {{on "click" (fn @controller.setTab "matches")}}
          type="button"
        >Open events</button>
        <button
          class="bookie-tab
            {{if (eq @controller.activeTab 'results') 'active'}}"
          {{on "click" (fn @controller.setTab "results")}}
          type="button"
        >Results</button>
        <button
          class="bookie-tab {{if (eq @controller.activeTab 'wallet') 'active'}}"
          {{on "click" (fn @controller.setTab "wallet")}}
          type="button"
        >My wallet</button>
        <button
          class="bookie-tab
            {{if (eq @controller.activeTab 'leaderboard') 'active'}}"
          {{on "click" (fn @controller.setTab "leaderboard")}}
          type="button"
        >Standings</button>
        <button
          class="bookie-tab {{if (eq @controller.activeTab 'rules') 'active'}}"
          {{on "click" (fn @controller.setTab "rules")}}
          type="button"
        >Rules</button>
        {{#if @controller.currentUser.staff}}
          <button
            class="bookie-tab bookie-tab-admin
              {{if (eq @controller.activeTab 'admin') 'active'}}"
            {{on "click" (fn @controller.setTab "admin")}}
            type="button"
          >
            {{dIcon "wrench"}}
            Admin
          </button>
        {{/if}}
      </div>
    </div>

    <nav class="bookie-mobile-tabbar" aria-label="Bookie mobile navigation">
      <div class="bookie-mobile-tabbar-inner">
        <button
          type="button"
          class="bookie-mobile-tab
            {{if (eq @controller.activeTab 'matches') 'active'}}"
          {{on "click" (fn @controller.setTab "matches")}}
        >
          {{dIcon "list"}}
          <span>Events</span>
        </button>
        <button
          type="button"
          class="bookie-mobile-tab
            {{if (eq @controller.activeTab 'results') 'active'}}"
          {{on "click" (fn @controller.setTab "results")}}
        >
          {{dIcon "chart-line"}}
          <span>Results</span>
        </button>
        <button
          type="button"
          class="bookie-mobile-tab
            {{if (eq @controller.activeTab 'wallet') 'active'}}"
          {{on "click" (fn @controller.setTab "wallet")}}
        >
          {{dIcon "book"}}
          <span>Wallet</span>
        </button>
        <button
          type="button"
          class="bookie-mobile-tab
            {{if (eq @controller.activeTab 'leaderboard') 'active'}}"
          {{on "click" (fn @controller.setTab "leaderboard")}}
        >
          {{dIcon "trophy"}}
          <span>Standings</span>
        </button>
        {{#if @controller.currentUser.staff}}
          <button
            type="button"
            class="bookie-mobile-tab
              {{if (eq @controller.activeTab 'admin') 'active'}}"
            {{on "click" (fn @controller.setTab "admin")}}
          >
            {{dIcon "wrench"}}
            <span>Admin</span>
          </button>
        {{/if}}
      </div>
    </nav>

    {{! ══════════════════════════════════════════════════ }}
    {{! PANEL: Open matches                                }}
    {{! ══════════════════════════════════════════════════ }}
    {{#if (eq @controller.activeTab "matches")}}
      <div class="bookie-panel">
        <div class="bookie-standings-tabs bookie-betmode-tabs">
          <button
            class="bookie-standings-tab
              {{if (eq @controller.betMode 'single') 'active'}}"
            {{on "click" (fn @controller.setBetMode "single")}}
            type="button"
          >
            Single bets
          </button>
          <button
            class="bookie-standings-tab
              {{if (eq @controller.betMode 'accumulator') 'active'}}"
            {{on "click" (fn @controller.setBetMode "accumulator")}}
            type="button"
          >
            Accumulator
          </button>
        </div>

        {{#if @controller.showSportFilter}}
          <div class="bookie-standings-tabs bookie-sport-filter">
            <button
              class="bookie-standings-tab
                {{if (eq @controller.sportFilter 'all') 'active'}}"
              {{on "click" (fn @controller.setSportFilter "all")}}
              type="button"
            >
              All
            </button>
            {{#each @controller.availableSports as |sport|}}
              <button
                class="bookie-standings-tab
                  {{if (eq @controller.sportFilter sport.key) 'active'}}"
                {{on "click" (fn @controller.setSportFilter sport.key)}}
                type="button"
              >
                {{sport.icon}}
                {{sport.label}}
              </button>
            {{/each}}
          </div>
        {{/if}}

        {{#if @controller.matches.length}}
          <div class="bookie-matches-grid">
            {{#each @controller.filteredMatches as |match|}}
              <div class="bookie-match-card {{if match.userBet 'has-bet'}}">

                {{#if match.competition}}
                  <div
                    class="bookie-match-competition"
                  >{{match.competition}}</div>
                {{/if}}

                <div class="bookie-match-teams">
                  <span class="bookie-team">{{match.home_team}}</span>
                  <span class="bookie-vs">vs</span>
                  <span class="bookie-team">{{match.away_team}}</span>
                </div>

                {{#if @controller.showSportFilter}}
                  <div class="bookie-match-sport">{{match.sport_icon}}
                    {{match.sport_label}}</div>
                {{/if}}

                {{#if (eq @controller.betMode "accumulator")}}
                  {{#if match.canBet}}
                    <div class="bookie-odds-row bookie-acca-odds-row">
                      <button
                        type="button"
                        class="bookie-odds-btn
                          {{if (eq match.accaChoice 'home') 'in-slip'}}"
                        {{on
                          "click"
                          (fn @controller.toggleAccaSelection match "home")
                        }}
                      >
                        <span
                          class="bookie-odds-team"
                        >{{match.home_team}}</span>
                        <span
                          class="bookie-odds-value"
                        >{{match.odds_home}}</span>
                      </button>
                      {{#if match.has_draw}}
                        <button
                          type="button"
                          class="bookie-odds-btn
                            {{if (eq match.accaChoice 'draw') 'in-slip'}}"
                          {{on
                            "click"
                            (fn @controller.toggleAccaSelection match "draw")
                          }}
                        >
                          <span class="bookie-odds-team">Draw</span>
                          <span
                            class="bookie-odds-value"
                          >{{match.odds_draw}}</span>
                        </button>
                      {{/if}}
                      <button
                        type="button"
                        class="bookie-odds-btn
                          {{if (eq match.accaChoice 'away') 'in-slip'}}"
                        {{on
                          "click"
                          (fn @controller.toggleAccaSelection match "away")
                        }}
                      >
                        <span
                          class="bookie-odds-team"
                        >{{match.away_team}}</span>
                        <span
                          class="bookie-odds-value"
                        >{{match.odds_away}}</span>
                      </button>
                    </div>
                    {{#if match.accaChoice}}
                      <div
                        class="bookie-acca-note bookie-acca-note--added"
                      >Added to your accumulator ↓</div>
                    {{else if match.userBet}}
                      <div class="bookie-acca-note">You already have a single
                        bet on this event.</div>
                    {{/if}}
                  {{else}}
                    <div class="bookie-closed-notice">Betting closed for this
                      event</div>
                  {{/if}}
                {{else}}
                  {{#if match.userBet}}
                    {{! Already placed a bet }}
                    <div class="bookie-existing-bet">
                      <div
                        class="bookie-bet-badge bet-{{match.userBet.choice}}"
                      >
                        {{match.userBetLabel}}
                        &nbsp;·&nbsp;{{match.userBet.amount}}
                        {{@controller.currency}}
                        &nbsp;@&nbsp;{{match.userBet.odds}}x &nbsp;→&nbsp;{{match.userBet.potential_payout}}
                        {{@controller.currency}}
                      </div>
                      {{#if match.canBet}}
                        <button
                          class="btn btn-small btn-danger"
                          {{on "click" (fn @controller.cancelBet match)}}
                          type="button"
                        >
                          Cancel bet
                        </button>
                      {{/if}}
                    </div>
                  {{else if match.canBet}}
                    {{! Bet form }}
                    <div class="bookie-bet-form">
                      <div class="bookie-odds-row">
                        <button
                          class="bookie-odds-btn
                            {{if (eq match.selectedChoice 'home') 'selected'}}"
                          {{on
                            "click"
                            (fn @controller.selectChoice match "home")
                          }}
                          type="button"
                        >
                          <span
                            class="bookie-odds-team"
                          >{{match.home_team}}</span>
                          <span
                            class="bookie-odds-value"
                          >{{match.odds_home}}</span>
                        </button>
                        {{#if match.has_draw}}
                          <button
                            class="bookie-odds-btn
                              {{if
                                (eq match.selectedChoice 'draw')
                                'selected'
                              }}"
                            {{on
                              "click"
                              (fn @controller.selectChoice match "draw")
                            }}
                            type="button"
                          >
                            <span class="bookie-odds-team">Draw</span>
                            <span
                              class="bookie-odds-value"
                            >{{match.odds_draw}}</span>
                          </button>
                        {{/if}}
                        <button
                          class="bookie-odds-btn
                            {{if (eq match.selectedChoice 'away') 'selected'}}"
                          {{on
                            "click"
                            (fn @controller.selectChoice match "away")
                          }}
                          type="button"
                        >
                          <span
                            class="bookie-odds-team"
                          >{{match.away_team}}</span>
                          <span
                            class="bookie-odds-value"
                          >{{match.odds_away}}</span>
                        </button>
                      </div>

                      {{#if match.selectedChoice}}
                        <div class="bookie-amount-row">
                          <input
                            class="bookie-amount-input"
                            type="number"
                            min="10"
                            max={{@controller.balance}}
                            placeholder="Amount (min 10)"
                            value={{match.betAmount}}
                            {{on "input" (fn @controller.setAmount match)}}
                          />
                          {{#if match.betAmount}}
                            <span class="bookie-payout-preview">
                              Win:
                              {{match.calcPayout}}
                              {{@controller.currency}}
                            </span>
                          {{/if}}
                          <button
                            class="btn btn-primary bookie-place-bet"
                            disabled={{match.betDisabled}}
                            {{on "click" (fn @controller.placeBet match)}}
                            type="button"
                          >
                            Place bet
                          </button>
                        </div>
                      {{/if}}

                      {{#if match.betError}}
                        <div class="bookie-error">{{match.betError}}</div>
                      {{/if}}
                    </div>
                  {{else}}
                    <div class="bookie-closed-notice">Betting closed for this
                      event</div>
                  {{/if}}
                {{/if}}

                <div class="bookie-match-deadline">Closes:
                  {{match.formattedDeadline}}</div>
                {{#if match.total_bets}}
                  <div class="bookie-match-market-stats">
                    {{match.total_coins}}
                    {{@controller.currency}}
                    ({{match.total_bets}}
                    {{if (eq match.total_bets 1) "bet" "bets"}})
                  </div>
                {{/if}}

              </div>
            {{/each}}
          </div>
        {{else}}
          <div class="bookie-empty">
            No events open for betting right now — check back soon!
          </div>
        {{/if}}

        {{#if
          (and
            (eq @controller.betMode "accumulator") @controller.accaSlip.length
          )
        }}
          <div class="bookie-acca-slip">
            <div class="bookie-acca-slip-header">
              <span class="bookie-acca-slip-title">🎯 Accumulator</span>
              <span class="bookie-acca-slip-count">
                {{@controller.accaSlip.length}}
                {{if
                  (eq @controller.accaSlip.length 1)
                  "selection"
                  "selections"
                }}
              </span>
              <button
                type="button"
                class="bookie-acca-slip-clear"
                {{on "click" @controller.clearAccaSlip}}
              >
                Clear
              </button>
              <button
                type="button"
                class="bookie-acca-slip-toggle"
                aria-expanded={{if
                  @controller.accaSlipCollapsed
                  "false"
                  "true"
                }}
                title={{if @controller.accaSlipCollapsed "Expand" "Collapse"}}
                {{on "click" @controller.toggleAccaSlipCollapsed}}
              >
                {{dIcon
                  (if @controller.accaSlipCollapsed "angle-down" "angle-up")
                }}
              </button>
            </div>

            {{#unless @controller.accaSlipCollapsed}}
              <div class="bookie-acca-slip-legs">
                {{#each @controller.accaSlip as |leg|}}
                  <div class="bookie-acca-slip-leg">
                    <div class="bookie-acca-slip-leg-info">
                      <span
                        class="bookie-acca-slip-leg-pick"
                      >{{leg.choiceLabel}}</span>
                      <span class="bookie-acca-slip-leg-match">{{leg.homeTeam}}
                        vs
                        {{leg.awayTeam}}</span>
                    </div>
                    <span class="bookie-acca-slip-leg-odds">{{leg.odds}}x</span>
                    <button
                      type="button"
                      class="bookie-acca-slip-leg-remove"
                      title="Remove selection"
                      {{on "click" (fn @controller.removeAccaLeg leg)}}
                    >×</button>
                  </div>
                {{/each}}
              </div>
            {{/unless}}

            <div class="bookie-acca-slip-summary">
              <span>Combined odds</span>
              <strong>{{@controller.accaCombinedOdds}}x</strong>
            </div>

            <div class="bookie-acca-slip-controls">
              <input
                class="bookie-amount-input bookie-acca-stake-input"
                type="number"
                min="10"
                max={{@controller.balance}}
                placeholder="Stake (min 10)"
                value={{@controller.accaStake}}
                {{on "input" @controller.setAccaStake}}
              />
              {{#if @controller.accaPotentialPayout}}
                <span class="bookie-payout-preview">
                  Win:
                  {{@controller.accaPotentialPayout}}
                  {{@controller.currency}}
                </span>
              {{/if}}
              <button
                type="button"
                class="btn btn-primary bookie-place-bet"
                disabled={{@controller.accaPlaceDisabled}}
                {{on "click" @controller.placeAccumulator}}
              >
                {{if @controller.accaPlacing "Placing…" "Place accumulator"}}
              </button>
            </div>

            {{#if @controller.accaNeedsMore}}
              <div class="bookie-acca-slip-hint">Add at least 2 selections to
                place an accumulator.</div>
            {{/if}}
            {{#if @controller.accaError}}
              <div class="bookie-error">{{@controller.accaError}}</div>
            {{/if}}
          </div>
        {{/if}}
      </div>
    {{/if}}

    {{! ══════════════════════════════════════════════════ }}
    {{! PANEL: Results                                     }}
    {{! ══════════════════════════════════════════════════ }}
    {{#if (eq @controller.activeTab "results")}}
      <div class="bookie-panel">
        <div class="bookie-standings-tabs bookie-results-tabs">
          <button
            class="bookie-standings-tab
              {{if (eq @controller.resultsSubTab 'my-results') 'active'}}"
            {{on "click" (fn @controller.setResultsSubTab "my-results")}}
            type="button"
          >
            Bets
          </button>
          <button
            class="bookie-standings-tab
              {{if (eq @controller.resultsSubTab 'accumulators') 'active'}}"
            {{on "click" (fn @controller.setResultsSubTab "accumulators")}}
            type="button"
          >
            Accas
          </button>
          <button
            class="bookie-standings-tab
              {{if (eq @controller.resultsSubTab 'achievements') 'active'}}"
            {{on "click" (fn @controller.setResultsSubTab "achievements")}}
            type="button"
          >
            Badges
          </button>
          <button
            class="bookie-standings-tab
              {{if (eq @controller.resultsSubTab 'stats') 'active'}}"
            {{on "click" (fn @controller.setResultsSubTab "stats")}}
            type="button"
          >
            Stats
          </button>
        </div>

        {{#if (eq @controller.resultsSubTab "my-results")}}
          {{#if @controller.settledMatches.length}}
            <div class="bookie-results-list">
              {{#each @controller.settledMatches as |match|}}
                <div
                  class="bookie-result-row
                    {{if match.detailsExpanded 'is-expanded'}}
                    {{if match.hasLeagueBreakdown 'has-breakdown'}}"
                >
                  <div class="bookie-result-main">
                    <div class="bookie-result-teams">
                      <span class="bookie-result-match">{{match.home_team}}
                        vs
                        {{match.away_team}}</span>
                      {{#if match.userBet}}
                        <span
                          class="bookie-result-pick {{match.pickStatusClass}}"
                        >
                          <span
                            class="bookie-result-pick-icon"
                          >{{match.pickStatusIcon}}</span>
                          You picked
                          {{match.userBetLabel}}
                          @
                          {{match.userBetOddsText}}
                        </span>
                      {{/if}}
                    </div>

                    <div class="bookie-result-trailing">
                      <div class="bookie-result-outcome">
                        <span class="bookie-result-outcome-label">Result:</span>
                        <span
                          class="bookie-result-outcome-value"
                        >{{match.resultText}}</span>
                      </div>
                      {{#if match.userBet}}
                        <div class="bookie-result-summary">
                          <div
                            class="bookie-result-score {{match.coinDeltaClass}}"
                          >
                            {{match.coinDeltaText}}
                          </div>
                          {{#if match.hasLeaguePoints}}
                            <div class="bookie-result-score-divider"></div>
                            <div
                              class="bookie-result-score
                                {{match.pointsDeltaClass}}"
                            >
                              {{match.pointsDeltaText}}
                            </div>
                          {{/if}}
                        </div>
                      {{/if}}

                      {{#if match.hasLeagueBreakdown}}
                        <button
                          class="bookie-result-toggle"
                          type="button"
                          aria-expanded={{if
                            match.detailsExpanded
                            "true"
                            "false"
                          }}
                          {{on
                            "click"
                            (fn @controller.toggleResultDetails match)
                          }}
                        >
                          {{dIcon
                            (if match.detailsExpanded "angle-up" "angle-down")
                          }}
                        </button>
                      {{/if}}
                    </div>
                  </div>

                  {{#if (and match.detailsExpanded match.hasLeagueBreakdown)}}
                    <div class="bookie-result-breakdown">
                      {{#each match.leaguePointsBreakdown as |entry|}}
                        <div class="bookie-result-breakdown-item">
                          +{{entry.points}}
                          {{entry.label}}
                        </div>
                      {{/each}}
                    </div>
                  {{/if}}
                </div>
              {{/each}}
            </div>
          {{else}}
            <div class="bookie-empty">No settled events yet.</div>
          {{/if}}
        {{else if (eq @controller.resultsSubTab "stats")}}
          {{#if @controller.resultsHasStats}}
            <div class="bookie-results-stats">
              <div class="bookie-results-stats-grid">
                <div class="bookie-stats-card">
                  <div class="bookie-stats-card-label">Prediction accuracy</div>
                  <div
                    class="bookie-stats-card-value"
                  >{{@controller.resultsHitRateText}}</div>
                </div>

                <div class="bookie-stats-card">
                  <div class="bookie-stats-card-label">Current streak</div>
                  <div class="bookie-stats-card-value">
                    {{@controller.resultsSummary.current_streak}}
                    {{#if @controller.resultsCurrentStreakFires}}
                      <span
                        class="bookie-stats-streak-fire"
                      >{{@controller.resultsCurrentStreakFires}}</span>
                    {{/if}}
                  </div>
                </div>

                <div class="bookie-stats-card">
                  <div class="bookie-stats-card-label">Best streak</div>
                  <div
                    class="bookie-stats-card-value"
                  >{{@controller.resultsSummary.best_streak}}</div>
                </div>

                <div class="bookie-stats-card">
                  <div class="bookie-stats-card-label">Periods won</div>
                  <div
                    class="bookie-stats-card-value"
                  >{{@controller.resultsSummary.periods_won}}</div>
                </div>
              </div>

              <div class="bookie-stats-panel">
                <div class="bookie-stats-panel-header">
                  <div>
                    <h3 class="bookie-stats-panel-title">Balance over time</h3>
                    <p class="bookie-stats-panel-desc">Your coin balance after
                      each settled event — bonuses and active bets not included.</p>
                  </div>
                  <span class="bookie-stats-panel-meta">Last
                    {{@controller.resultsPointsTimeline.length}}
                    settled events</span>
                </div>

                <BookieResultsChart
                  @points={{@controller.resultsPointsTimeline}}
                  @currency={{@controller.currency}}
                />
              </div>

              <div class="bookie-results-stats-lower">
                <div class="bookie-stats-panel">
                  <div class="bookie-stats-panel-header">
                    <div>
                      <h3 class="bookie-stats-panel-title">Prediction breakdown</h3>
                      <p class="bookie-stats-panel-desc">How often you picked
                        the right outcome.</p>
                    </div>
                  </div>

                  <div class="bookie-stats-breakdown-bar" aria-hidden="true">
                    <div
                      class="bookie-stats-breakdown-segment is-win"
                      style={{@controller.resultsCorrectWidthStyle}}
                    ></div>
                    <div
                      class="bookie-stats-breakdown-segment is-loss"
                      style={{@controller.resultsWrongWidthStyle}}
                    ></div>
                  </div>

                  <div class="bookie-stats-breakdown-legend">
                    <div class="bookie-stats-breakdown-item">
                      <span class="bookie-stats-breakdown-dot is-win"></span>
                      <span>Correct</span>
                      <strong>{{@controller.resultsWins}}</strong>
                    </div>
                    <div class="bookie-stats-breakdown-item">
                      <span class="bookie-stats-breakdown-dot is-loss"></span>
                      <span>Wrong</span>
                      <strong>{{@controller.resultsLosses}}</strong>
                    </div>
                  </div>
                </div>

                <div class="bookie-stats-panel">
                  <div class="bookie-stats-panel-header">
                    <div>
                      <h3 class="bookie-stats-panel-title">Recent form</h3>
                      <p
                        class="bookie-stats-panel-desc"
                      >{{@controller.resultsRecentFormSummary}}</p>
                    </div>
                  </div>

                  <div class="bookie-stats-form-row">
                    {{#each @controller.resultsRecentForm as |entry|}}
                      <div
                        class="bookie-stats-form-chip
                          {{if (eq entry.result 'W') 'is-win' 'is-loss'}}"
                      >
                        {{entry.result}}
                      </div>
                    {{/each}}
                  </div>
                </div>
              </div>

              <div class="bookie-stats-panel">
                <div class="bookie-stats-panel-header">
                  <div>
                    <h3 class="bookie-stats-panel-title">Your betting profile</h3>
                    <p class="bookie-stats-panel-desc">A quick read on your
                      Bookie performance so far.</p>
                  </div>
                </div>

                <div class="bookie-stats-summary-list">
                  <div class="bookie-stats-summary-row">
                    <span>Total settled bets</span>
                    <strong
                    >{{@controller.resultsSummary.total_settled_bets}}</strong>
                  </div>
                  <div class="bookie-stats-summary-row">
                    <span>Coin profit/loss</span>
                    <strong
                      class={{@controller.resultsCoinDeltaClass}}
                    >{{@controller.resultsCoinDeltaText}}</strong>
                  </div>
                  <div class="bookie-stats-summary-row">
                    <span>Average winning odds</span>
                    <strong
                    >{{@controller.resultsAverageWinningOddsText}}</strong>
                  </div>
                  <div class="bookie-stats-summary-row">
                    <span>Biggest win</span>
                    <strong
                      class="bet-status-won"
                    >{{@controller.resultsBiggestWinText}}</strong>
                  </div>
                  <div class="bookie-stats-summary-row">
                    <span>Best team</span>
                    <strong>{{@controller.resultsBestTeamText}}</strong>
                  </div>
                  {{#if @controller.resultsSummary.best_team}}
                    <div class="bookie-stats-summary-subrow">
                      <span>Net result with
                        {{@controller.resultsSummary.best_team}}</span>
                      <strong
                        class={{@controller.resultsBestTeamProfitClass}}
                      >{{@controller.resultsBestTeamProfitText}}</strong>
                    </div>
                  {{/if}}
                </div>
              </div>
            </div>
          {{else}}
            <div class="bookie-empty">No personal stats yet — settle a few
              events first.</div>
          {{/if}}
        {{else if (eq @controller.resultsSubTab "achievements")}}
          <div class="bookie-stats-panel bookie-achievements-panel">
            <div class="bookie-stats-panel-header">
              <div>
                <h3 class="bookie-stats-panel-title">Achievements</h3>
                <p class="bookie-stats-panel-desc">Unlock milestones as you play
                  Bookie.</p>
              </div>
              <span class="bookie-stats-panel-meta">
                {{@controller.resultsAchievementsUnlockedCount}}
                /
                {{@controller.resultsAchievementsTotalCount}}
                unlocked
              </span>
            </div>

            <div class="bookie-achievements-grid">
              {{#each @controller.resultsAchievements as |achievement|}}
                <div
                  class="bookie-achievement-card
                    {{if achievement.earned 'is-earned' 'is-locked'}}"
                >
                  <div class="bookie-achievement-image-wrap">
                    <img
                      class="bookie-achievement-image"
                      src={{achievement.image_url}}
                      alt
                      loading="lazy"
                    />
                  </div>
                  <div class="bookie-achievement-copy">
                    <h4
                      class="bookie-achievement-title"
                    >{{achievement.title}}</h4>
                    <p
                      class="bookie-achievement-desc"
                    >{{achievement.description}}</p>
                  </div>
                  <span class="bookie-achievement-status">
                    {{if achievement.earned "Unlocked" "Locked"}}
                  </span>
                </div>
              {{/each}}
            </div>
          </div>
        {{else if (eq @controller.resultsSubTab "accumulators")}}
          {{#if @controller.accumulators.length}}
            <div class="bookie-acca-list">
              {{#each @controller.accumulators as |acc|}}
                <div class="bookie-acca-card {{acc.statusClass}}">
                  <div class="bookie-acca-card-header">
                    <span
                      class="bookie-acca-card-status"
                    >{{acc.statusLabel}}</span>
                    <span class="bookie-acca-card-meta">
                      {{acc.legs.length}}-leg ·
                      {{acc.combined_odds}}x
                    </span>
                  </div>

                  <div class="bookie-acca-card-legs">
                    {{#each acc.legs as |leg|}}
                      <div class="bookie-acca-card-leg">
                        <span
                          class="bookie-acca-leg-icon {{leg.legStatusClass}}"
                        >{{leg.legStatusIcon}}</span>
                        <span
                          class="bookie-acca-leg-pick"
                        >{{leg.choice_label}}</span>
                        <span class="bookie-acca-leg-match">{{leg.home_team}}
                          vs
                          {{leg.away_team}}</span>
                        <span class="bookie-acca-leg-odds">{{leg.odds}}x</span>
                      </div>
                    {{/each}}
                  </div>

                  <div class="bookie-acca-card-footer">
                    <div class="bookie-acca-card-figures">
                      <span class="bookie-acca-card-stake">Stake:
                        {{acc.amount}}
                        {{@controller.currency}}</span>
                      {{#if acc.isWon}}
                        <span
                          class="bookie-acca-card-payout bet-status-won"
                        >+{{acc.payout}} {{@controller.currency}}</span>
                      {{else if acc.isPending}}
                        <span class="bookie-acca-card-payout">To win:
                          {{acc.potential_payout}}
                          {{@controller.currency}}</span>
                      {{/if}}
                    </div>
                    {{#if acc.isPending}}
                      <button
                        type="button"
                        class="btn btn-small btn-danger"
                        {{on "click" (fn @controller.cancelAccumulator acc)}}
                      >
                        Cancel
                      </button>
                    {{/if}}
                  </div>
                </div>
              {{/each}}
            </div>
          {{else}}
            <div class="bookie-empty">No accumulators yet — build one from the
              Open events tab.</div>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}

    {{! ══════════════════════════════════════════════════ }}
    {{! PANEL: Wallet                                      }}
    {{! ══════════════════════════════════════════════════ }}
    {{#if (eq @controller.activeTab "wallet")}}
      <div class="bookie-panel">
        <div class="bookie-wallet-balance">
          Balance:
          <strong>{{@controller.walletBalance}}
            {{@controller.currency}}</strong>
        </div>

        <div class="bookie-notification-pref">
          <span class="bookie-notification-pref-label">Receive notifications</span>
          <button
            type="button"
            class="bookie-toggle-btn
              {{if @controller.notificationsEnabled 'is-on'}}"
            {{on "click" @controller.toggleNotifications}}
          >
            <span class="bookie-toggle-knob"></span>
          </button>
        </div>

        <h3>Recent transactions</h3>
        {{#if @controller.walletTransactions.length}}
          <table class="bookie-tx-table">
            <thead>
              <tr><th>Date</th><th>Description</th><th>Amount</th></tr>
            </thead>
            <tbody>
              {{#each @controller.walletTransactions as |tx|}}
                <tr class={{if tx.isPositive "tx-positive" "tx-negative"}}>
                  <td>{{tx.formattedDate}}</td>
                  <td>{{tx.description}}</td>
                  <td class="tx-amount">
                    {{#if tx.isPositive}}+{{/if}}{{tx.amount}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <div class="bookie-empty">No transactions yet.</div>
        {{/if}}
      </div>
    {{/if}}

    {{! ══════════════════════════════════════════════════ }}
    {{! PANEL: Standings                                   }}
    {{! ══════════════════════════════════════════════════ }}
    {{#if (eq @controller.activeTab "leaderboard")}}
      <div class="bookie-panel bookie-standings-panel">

        {{! Sub-tab navigation }}
        <div class="bookie-standings-tabs">
          <button
            class="bookie-standings-tab
              {{if (eq @controller.standingsTab 'league-table') 'active'}}"
            {{on "click" (fn @controller.setStandingsTab "league-table")}}
            type="button"
          >
            League Table
          </button>
          <button
            class="bookie-standings-tab
              {{if (eq @controller.standingsTab 'money-sprint') 'active'}}"
            {{on "click" (fn @controller.setStandingsTab "money-sprint")}}
            type="button"
          >
            Money Sprint
          </button>
        </div>

        {{! ── League Table ── }}
        {{#if (eq @controller.standingsTab "league-table")}}
          <div class="bookie-standings-card">
            <div class="bookie-standings-card-header">
              <div>
                <h2 class="bookie-standings-title">League Table</h2>
                <p class="bookie-standings-desc">
                  Resets every two months. Rewards form, consistency and
                  streaks.
                  <button
                    type="button"
                    class="bookie-inline-link"
                    {{on "click" (fn @controller.setTab "rules")}}
                  >
                    Read the rules
                  </button>
                </p>
              </div>
              {{#if @controller.currentPeriodLabel}}
                <span class="bookie-period-pill">Period:
                  {{@controller.currentPeriodLabel}}</span>
              {{/if}}
            </div>

            {{#if @controller.leaguePodium.length}}
              {{! Podium: top 3 — order: 2nd left, 1st centre, 3rd right via CSS }}
              <div class="bookie-podium">
                {{#each @controller.leaguePodium as |entry|}}
                  <div class="bookie-podium-card rank-{{entry.rank}}">
                    <span class="bookie-podium-rank-num">{{entry.rank}}</span>
                    <span class="bookie-podium-medal">
                      {{#if (eq entry.rank 1)}}🥇{{else if
                        (eq entry.rank 2)
                      }}🥈{{else}}🥉{{/if}}
                    </span>
                    <span class="bookie-podium-rank-pill">
                      {{#if (eq entry.rank 1)}}1st{{else if
                        (eq entry.rank 2)
                      }}2nd{{else}}3rd{{/if}}
                    </span>
                    <span class="bookie-podium-name">{{entry.username}}</span>
                    <span class="bookie-podium-value">{{entry.points}}
                      pts</span>
                  </div>
                {{/each}}
              </div>

              {{! Rest of the table (#4+) }}
              {{#if @controller.leagueRest.length}}
                <table class="bookie-lb-table bookie-standings-rest">
                  <tbody>
                    {{#each @controller.leagueRest as |entry|}}
                      <tr>
                        <td class="lb-rank-cell">#{{entry.rank}}</td>
                        <td><a
                            href="/u/{{entry.username}}"
                          >{{entry.username}}</a></td>
                        <td class="lb-balance">{{entry.points}} pts</td>
                      </tr>
                    {{/each}}
                  </tbody>
                </table>
              {{/if}}
            {{else}}
              <div class="bookie-empty">No points yet this period — place your
                first bet!</div>
            {{/if}}

            {{! ── Previous periods ── }}
            {{#if @controller.periodHistory.length}}
              <div class="bookie-prev-period">
                <h3 class="bookie-prev-period-title">Previous periods</h3>

                {{! Period selector pills }}
                <div class="bookie-period-selector">
                  {{#each @controller.periodHistory as |period|}}
                    <button
                      class="bookie-period-pill-btn
                        {{if
                          (eq @controller.effectivePeriodKey period.period_key)
                          'active'
                        }}"
                      {{on
                        "click"
                        (fn @controller.selectPeriod period.period_key)
                      }}
                      type="button"
                    >
                      {{period.label}}
                    </button>
                  {{/each}}
                </div>

                {{! Top 3 for selected period }}
                {{#if @controller.selectedPeriod}}
                  <div class="bookie-prev-period-list">
                    {{#each @controller.selectedPeriod.top3 as |entry|}}
                      <div class="bookie-prev-period-row">
                        <span class="bookie-prev-medal">
                          {{#if (eq entry.rank 1)}}🥇{{else if
                            (eq entry.rank 2)
                          }}🥈{{else}}🥉{{/if}}
                        </span>
                        <span class="bookie-prev-name">
                          <a href="/u/{{entry.username}}">{{entry.username}}</a>
                        </span>
                        <span class="bookie-prev-pts">{{entry.points}}
                          pts</span>
                      </div>
                    {{/each}}
                  </div>
                {{/if}}
              </div>
            {{/if}}

          </div>
        {{/if}}

        {{! ── Money Sprint ── }}
        {{#if (eq @controller.standingsTab "money-sprint")}}
          <div class="bookie-standings-card">
            <div class="bookie-standings-card-header">
              <div>
                <h2 class="bookie-standings-title">Money Sprint</h2>
                <p class="bookie-standings-desc">
                  Most
                  {{@controller.currency}}
                  won this month. Everyone starts back at zero on the 1st.
                  <button
                    type="button"
                    class="bookie-inline-link"
                    {{on "click" (fn @controller.setTab "rules")}}
                  >
                    Read the rules
                  </button>
                </p>
              </div>
              <span
                class="bookie-period-pill"
              >{{@controller.sprintMonthLabel}}</span>
            </div>

            {{#if @controller.sprintPodium.length}}
              <div class="bookie-podium">
                {{#each @controller.sprintPodium as |entry|}}
                  <div class="bookie-podium-card rank-{{entry.rank}}">
                    <span class="bookie-podium-rank-num">{{entry.rank}}</span>
                    <span class="bookie-podium-medal">
                      {{#if (eq entry.rank 1)}}🥇{{else if
                        (eq entry.rank 2)
                      }}🥈{{else}}🥉{{/if}}
                    </span>
                    <span class="bookie-podium-rank-pill">
                      {{#if (eq entry.rank 1)}}1st{{else if
                        (eq entry.rank 2)
                      }}2nd{{else}}3rd{{/if}}
                    </span>
                    <span class="bookie-podium-name">{{entry.username}}</span>
                    <span
                      class="bookie-podium-value bookie-podium-value--profit
                        {{entry.profitClass}}"
                    >{{entry.profitText}} {{@controller.currency}}</span>
                  </div>
                {{/each}}
              </div>

              {{#if @controller.sprintRest.length}}
                <table class="bookie-lb-table bookie-standings-rest">
                  <tbody>
                    {{#each @controller.sprintRest as |entry|}}
                      <tr>
                        <td class="lb-rank-cell">#{{entry.rank}}</td>
                        <td><a
                            href="/u/{{entry.username}}"
                          >{{entry.username}}</a></td>
                        <td class="lb-balance {{entry.profitClass}}">
                          {{entry.profitText}}
                          {{@controller.currency}}
                        </td>
                      </tr>
                    {{/each}}
                  </tbody>
                </table>
              {{/if}}
            {{else}}
              <div class="bookie-empty">
                No settled bets yet this month — the sprint starts with your
                first result!
              </div>
            {{/if}}

            {{! ── Previous sprints ── }}
            {{#if @controller.sprintHistory.length}}
              <div class="bookie-prev-period">
                <h3 class="bookie-prev-period-title">Previous sprints</h3>

                <div class="bookie-period-selector">
                  {{#each @controller.sprintHistory as |month|}}
                    <button
                      class="bookie-period-pill-btn
                        {{if
                          (eq @controller.effectiveSprintMonth month.month_key)
                          'active'
                        }}"
                      {{on
                        "click"
                        (fn @controller.selectSprintMonth month.month_key)
                      }}
                      type="button"
                    >
                      {{month.label}}
                    </button>
                  {{/each}}
                </div>

                {{#if @controller.selectedSprint}}
                  <div class="bookie-prev-period-list">
                    {{#each @controller.selectedSprint.top3 as |entry|}}
                      <div class="bookie-prev-period-row">
                        <span class="bookie-prev-medal">
                          {{#if (eq entry.rank 1)}}🥇{{else if
                            (eq entry.rank 2)
                          }}🥈{{else}}🥉{{/if}}
                        </span>
                        <span class="bookie-prev-name">
                          <a href="/u/{{entry.username}}">{{entry.username}}</a>
                        </span>
                        <span class="bookie-prev-pts">{{entry.profit}}
                          {{@controller.currency}}</span>
                      </div>
                    {{/each}}
                  </div>
                {{/if}}
              </div>
            {{/if}}
          </div>
        {{/if}}

      </div>
    {{/if}}

    {{! ══════════════════════════════════════════════════ }}
    {{! PANEL: Rules                                       }}
    {{! ══════════════════════════════════════════════════ }}
    {{#if (eq @controller.activeTab "rules")}}
      <div class="bookie-panel bookie-rules-panel">

        <div class="bookie-rules-intro">
          Bookie runs two parallel competitions. Both are purely virtual — no
          real money involved. Every member starts with
          {{@controller.currency}}
          to play with. Good luck! ⚽
        </div>

        {{! Accumulators }}
        <div class="bookie-rules-section">
          <div class="bookie-rules-section-header">
            <span class="bookie-rules-icon">🎯</span>
            <h2 class="bookie-rules-title">Accumulators</h2>
            <span class="bookie-period-pill">New</span>
          </div>
          <p class="bookie-rules-tagline">Combine 2+ picks into one bet for a
            bigger payout — but every leg has to win.</p>

          <h3 class="bookie-rules-subheading">How it works</h3>
          <ul class="bookie-rules-list">
            <li>Switch to
              <strong>Accumulator</strong>
              mode on the Open events tab and tap an outcome on each event you
              want to include.</li>
            <li>Your odds multiply: a 2.00 and a 3.00 pick become a 6.00
              accumulator — a 50-coin stake then returns 300 coins.</li>
            <li><strong>All legs must win.</strong>
              One wrong pick and the whole accumulator is lost.</li>
            <li>Land a higher-odds accumulator (combined odds of
              <strong>4.0+</strong>) and you also earn
              <strong>+5 League Table points</strong>
              — small on purpose; accumulators are mainly about the Money
              Sprint.</li>
            <li>You can cancel an accumulator for a full refund until its first
              event kicks off. If an event is removed, the accumulator is voided
              and your stake refunded.</li>
          </ul>
        </div>

        {{! League Table }}
        <div class="bookie-rules-section">
          <div class="bookie-rules-section-header">
            <span class="bookie-rules-icon">🏆</span>
            <h2 class="bookie-rules-title">League Table</h2>
            <span class="bookie-period-pill">Resets every two months</span>
          </div>
          <p class="bookie-rules-tagline">Our ⚽ football prediction ladder —
            rewards picking accuracy, consistency and hot streaks.</p>

          <h3 class="bookie-rules-subheading">How points are earned</h3>
          <div class="bookie-rules-grid">
            <div class="bookie-rules-row">
              <span class="bookie-rules-pts">+2</span>
              <div>
                <strong>Participation</strong>
                <span>Placing any bet on an event</span>
              </div>
            </div>
            <div class="bookie-rules-row">
              <span class="bookie-rules-pts">+10</span>
              <div>
                <strong>Correct pick</strong>
                <span>Your predicted outcome was right</span>
              </div>
            </div>
            <div class="bookie-rules-row">
              <span class="bookie-rules-pts">+odds bonus</span>
              <div>
                <strong>Odds bonus</strong>
                <span>Correct pick on a longer shot earns extra pts — calculated
                  as
                  <em>round((odds − 1) × 4)</em>. A 3.50 draw pays +10 pts on
                  top of the base reward.</span>
              </div>
            </div>
            <div class="bookie-rules-row">
              <span class="bookie-rules-pts">+8 / +18 / +35</span>
              <div>
                <strong>Streak bonus</strong>
                <span>3 correct picks in a row:
                  <strong>+8</strong>
                  · 5 in a row:
                  <strong>+18</strong>
                  · 8 in a row:
                  <strong>+35</strong>
                  · then
                  <strong>+5</strong>
                  for every win beyond 8</span>
              </div>
            </div>
            <div class="bookie-rules-row">
              <span class="bookie-rules-pts">+5</span>
              <div>
                <strong>Accumulator</strong>
                <span>Land a full accumulator at 4.0+ combined odds. See the
                  Accumulators section below.</span>
              </div>
            </div>
          </div>

          <h3 class="bookie-rules-subheading">Periods</h3>
          <p class="bookie-rules-body">
            The league table resets every two months: Aug–Sep · Oct–Nov ·
            Dec–Jan · Feb–Mar · Apr–May · Jun–Jul. At the end of each period the
            top 3 are snapshotted — you can view previous winners in the
            Standings tab.
          </p>

          <h3 class="bookie-rules-subheading">Important notes</h3>
          <p class="bookie-rules-body">
            Bet size does not affect your points. A minimum 10-coin bet on an
            event earns the same points as a max bet. The league table is purely
            about picking the right outcome, not risk-taking.
          </p>
        </div>

        {{! Money Sprint }}
        <div class="bookie-rules-section">
          <div class="bookie-rules-section-header">
            <span class="bookie-rules-icon">💰</span>
            <h2 class="bookie-rules-title">Money Sprint</h2>
            <span class="bookie-period-pill">Resets every month</span>
          </div>
          <p class="bookie-rules-tagline">Who wins the most
            {{@controller.currency}}
            this month? A fresh race every month.</p>

          <h3 class="bookie-rules-subheading">How it works</h3>
          <ul class="bookie-rules-list">
            <li>You're ranked on your
              <strong>net profit for the month</strong>
              — everything you win minus everything you stake.</li>
            <li>Every month
              <strong>everyone starts back at zero</strong>
              on the 1st, so a bad month is never the end of your run. Your
              wallet keeps going as normal — only the scoreboard resets.</li>
            <li>Only
              <strong>settled bets</strong>
              count, in the month they settle: singles and accumulators alike.
              Weekly bonuses, gifted
              {{@controller.currency}}
              and refunds don't count — this is about your betting, not
              handouts.</li>
            <li>Level on profit? The player who got there in
              <strong>fewer bets</strong>
              ranks higher.</li>
            <li>At the end of each month the
              <strong>top 3 are saved</strong>
              as winners — you can browse past sprints in the Standings tab.</li>
          </ul>

          <h3 class="bookie-rules-subheading">How coins work</h3>
          <div class="bookie-rules-grid">
            <div class="bookie-rules-row">
              <span
                class="bookie-rules-pts bookie-rules-pts--start"
              >1,000</span>
              <div>
                <strong>Starting balance</strong>
                <span>Every member begins the season with 1,000
                  {{@controller.currency}}</span>
              </div>
            </div>
            <div class="bookie-rules-row">
              <span class="bookie-rules-pts bookie-rules-pts--bonus">+100</span>
              <div>
                <strong>Weekly bonus</strong>
                <span>100 free
                  {{@controller.currency}}
                  deposited every Monday — keep coming back!</span>
              </div>
            </div>
            <div class="bookie-rules-row">
              <span class="bookie-rules-pts bookie-rules-pts--win">Win</span>
              <div>
                <strong>Bet winnings</strong>
                <span>Correct bets pay out at the quoted odds. A 100-coin bet at
                  3.50 returns 350 coins.</span>
              </div>
            </div>
            <div class="bookie-rules-row">
              <span class="bookie-rules-pts bookie-rules-pts--loss">Loss</span>
              <div>
                <strong>Losing bets</strong>
                <span>Your staked coins are deducted when a bet loses. Budget
                  wisely — you can't go below zero.</span>
              </div>
            </div>
          </div>

          <h3 class="bookie-rules-subheading">Strategy</h3>
          <p class="bookie-rules-body">
            Where the League Table rewards being right, the Money Sprint rewards
            how you stake. Chasing long shots can win you the month or sink it,
            and because it's only four weeks, one big call carries real weight.
            Bet size matters here — unlike the League Table, a 500-coin win
            counts for far more than a 10-coin one.
          </p>
        </div>

        {{! General rules }}
        <div class="bookie-rules-section bookie-rules-section--general">
          <h3 class="bookie-rules-subheading">General rules</h3>
          <ul class="bookie-rules-list">
            <li>One bet per event, per person. No changing your mind after the
              deadline.</li>
            <li>You can cancel a pending bet before the event deadline — your
              coins are refunded.</li>
            <li>Admins set the odds and settle events. Results are final once
              settled.</li>
            <li>This is for fun only. Coins have no monetary value.</li>
          </ul>
        </div>

      </div>
    {{/if}}

    {{! ══════════════════════════════════════════════════ }}
    {{! PANEL: Admin (staff only)                          }}
    {{! ══════════════════════════════════════════════════ }}
    {{#if
      (and (eq @controller.activeTab "admin") @controller.currentUser.staff)
    }}
      <div class="bookie-panel bookie-admin-panel">

        <div class="bookie-standings-tabs bookie-admin-subtabs">
          <button
            type="button"
            class="bookie-standings-tab bookie-admin-subtab
              {{if (eq @controller.adminSubTab 'events') 'active'}}"
            {{on "click" (fn @controller.setAdminSubTab "events")}}
          >
            Events
          </button>
          <button
            type="button"
            class="bookie-standings-tab bookie-admin-subtab
              {{if (eq @controller.adminSubTab 'management') 'active'}}"
            {{on "click" (fn @controller.setAdminSubTab "management")}}
          >
            Management
          </button>
        </div>

        {{#if @controller.adminError}}
          <div class="bookie-error">{{@controller.adminError}}</div>
        {{/if}}

        {{#if (eq @controller.adminSubTab "events")}}
          <h2>Create new event</h2>
          <div class="bookie-admin-form">
            {{#if @controller.showSportSelect}}
              <div class="bookie-form-row">
                <label>Sport</label>
                <div class="bookie-sport-select">
                  {{#each @controller.creatableSports as |sport|}}
                    <button
                      type="button"
                      class="bookie-standings-tab
                        {{if (eq @controller.nmSport sport.key) 'active'}}"
                      {{on
                        "click"
                        (fn @controller.updateFieldValue "nmSport" sport.key)
                      }}
                    >
                      {{sport.icon}}
                      {{sport.label}}
                    </button>
                  {{/each}}
                </div>
              </div>
            {{/if}}
            <div class="bookie-form-row">
              <label>{{@controller.nmHomeLabel}}</label>
              <input
                class="bookie-input"
                type="text"
                autocomplete="off"
                value={{@controller.nmHomeTeam}}
                placeholder="e.g. Arsenal"
                {{on "input" (fn @controller.updateField "nmHomeTeam")}}
              />
              {{#if @controller.newHomeClubSuggestions.length}}
                <div class="bookie-club-suggestions">
                  {{#each @controller.newHomeClubSuggestions as |club|}}
                    <button
                      class="bookie-club-suggestion-btn"
                      type="button"
                      {{on
                        "click"
                        (fn @controller.chooseClub "nmHomeTeam" club.name)
                      }}
                    >
                      <span>{{club.name}}</span>
                      {{#if club.aliases.length}}
                        <span class="bookie-club-suggestion-meta">{{get
                            club.aliases
                            "0"
                          }}</span>
                      {{/if}}
                    </button>
                  {{/each}}
                </div>
              {{/if}}
            </div>
            <div class="bookie-form-row">
              <label>{{@controller.nmAwayLabel}}</label>
              <input
                class="bookie-input"
                type="text"
                autocomplete="off"
                value={{@controller.nmAwayTeam}}
                placeholder="e.g. Chelsea"
                {{on "input" (fn @controller.updateField "nmAwayTeam")}}
              />
              {{#if @controller.newAwayClubSuggestions.length}}
                <div class="bookie-club-suggestions">
                  {{#each @controller.newAwayClubSuggestions as |club|}}
                    <button
                      class="bookie-club-suggestion-btn"
                      type="button"
                      {{on
                        "click"
                        (fn @controller.chooseClub "nmAwayTeam" club.name)
                      }}
                    >
                      <span>{{club.name}}</span>
                      {{#if club.aliases.length}}
                        <span class="bookie-club-suggestion-meta">{{get
                            club.aliases
                            "0"
                          }}</span>
                      {{/if}}
                    </button>
                  {{/each}}
                </div>
              {{/if}}
            </div>
            <div class="bookie-form-row">
              <label>Competition (optional)</label>
              <input
                class="bookie-input"
                type="text"
                value={{@controller.nmCompetition}}
                placeholder="e.g. Premier League · FA Cup · Champions League"
                {{on "input" (fn @controller.updateField "nmCompetition")}}
              />
            </div>
            <div class="bookie-form-row bookie-odds-form-row">
              <div>
                <label>Odds: home win</label>
                <input
                  class="bookie-input bookie-odds-input"
                  type="number"
                  step="0.05"
                  min="1.01"
                  value={{@controller.nmOddsHome}}
                  {{on "input" (fn @controller.updateField "nmOddsHome")}}
                />
              </div>
              {{#if @controller.nmHasDraw}}
                <div>
                  <label>Odds: draw</label>
                  <input
                    class="bookie-input bookie-odds-input"
                    type="number"
                    step="0.05"
                    min="1.01"
                    value={{@controller.nmOddsDraw}}
                    {{on "input" (fn @controller.updateField "nmOddsDraw")}}
                  />
                </div>
              {{/if}}
              <div>
                <label>Odds: away win</label>
                <input
                  class="bookie-input bookie-odds-input"
                  type="number"
                  step="0.05"
                  min="1.01"
                  value={{@controller.nmOddsAway}}
                  {{on "input" (fn @controller.updateField "nmOddsAway")}}
                />
              </div>
            </div>
            <div class="bookie-form-row">
              <label>Deadline (kick-off time)</label>
              <input
                class="bookie-input"
                type="datetime-local"
                value={{@controller.nmDeadline}}
                {{on "input" (fn @controller.updateField "nmDeadline")}}
              />
              <span class="bookie-form-help">
                Saved from your local timezone:
                {{@controller.browserTimeZone}}
              </span>
            </div>
            <button
              class="btn btn-primary"
              {{on "click" @controller.createMatch}}
              type="button"
            >
              Create event
            </button>
          </div>

          <h2 class="bookie-section-title">Open events</h2>
          {{#if @controller.adminMatches.length}}
            {{#each @controller.adminMatches as |match|}}
              <div class="bookie-admin-match-row">
                {{#if (eq @controller.editingMatchId match.id)}}
                  <div class="bookie-admin-edit-grid">
                    <div class="bookie-form-row">
                      <label>Home team</label>
                      <input
                        class="bookie-input"
                        type="text"
                        autocomplete="off"
                        value={{@controller.emHomeTeam}}
                        {{on "input" (fn @controller.updateField "emHomeTeam")}}
                      />
                      {{#if @controller.editHomeClubSuggestions.length}}
                        <div class="bookie-club-suggestions">
                          {{#each
                            @controller.editHomeClubSuggestions
                            as |club|
                          }}
                            <button
                              class="bookie-club-suggestion-btn"
                              type="button"
                              {{on
                                "click"
                                (fn
                                  @controller.chooseClub "emHomeTeam" club.name
                                )
                              }}
                            >
                              <span>{{club.name}}</span>
                              {{#if club.aliases.length}}
                                <span class="bookie-club-suggestion-meta">{{get
                                    club.aliases
                                    "0"
                                  }}</span>
                              {{/if}}
                            </button>
                          {{/each}}
                        </div>
                      {{/if}}
                    </div>
                    <div class="bookie-form-row">
                      <label>Away team</label>
                      <input
                        class="bookie-input"
                        type="text"
                        autocomplete="off"
                        value={{@controller.emAwayTeam}}
                        {{on "input" (fn @controller.updateField "emAwayTeam")}}
                      />
                      {{#if @controller.editAwayClubSuggestions.length}}
                        <div class="bookie-club-suggestions">
                          {{#each
                            @controller.editAwayClubSuggestions
                            as |club|
                          }}
                            <button
                              class="bookie-club-suggestion-btn"
                              type="button"
                              {{on
                                "click"
                                (fn
                                  @controller.chooseClub "emAwayTeam" club.name
                                )
                              }}
                            >
                              <span>{{club.name}}</span>
                              {{#if club.aliases.length}}
                                <span class="bookie-club-suggestion-meta">{{get
                                    club.aliases
                                    "0"
                                  }}</span>
                              {{/if}}
                            </button>
                          {{/each}}
                        </div>
                      {{/if}}
                    </div>
                    <div class="bookie-form-row bookie-admin-edit-title">
                      <label>Competition (optional)</label>
                      <input
                        class="bookie-input"
                        type="text"
                        value={{@controller.emCompetition}}
                        placeholder="e.g. Premier League · FA Cup"
                        {{on
                          "input"
                          (fn @controller.updateField "emCompetition")
                        }}
                      />
                    </div>
                    <div class="bookie-form-row">
                      <label>Home odds</label>
                      <input
                        class="bookie-input bookie-odds-input"
                        type="number"
                        step="0.05"
                        min="1.01"
                        value={{@controller.emOddsHome}}
                        {{on "input" (fn @controller.updateField "emOddsHome")}}
                      />
                    </div>
                    {{#if @controller.emHasDraw}}
                      <div class="bookie-form-row">
                        <label>Draw odds</label>
                        <input
                          class="bookie-input bookie-odds-input"
                          type="number"
                          step="0.05"
                          min="1.01"
                          value={{@controller.emOddsDraw}}
                          {{on
                            "input"
                            (fn @controller.updateField "emOddsDraw")
                          }}
                        />
                      </div>
                    {{/if}}
                    <div class="bookie-form-row">
                      <label>Away odds</label>
                      <input
                        class="bookie-input bookie-odds-input"
                        type="number"
                        step="0.05"
                        min="1.01"
                        value={{@controller.emOddsAway}}
                        {{on "input" (fn @controller.updateField "emOddsAway")}}
                      />
                    </div>
                    <div class="bookie-form-row bookie-admin-edit-title">
                      <label>Deadline (kick-off time)</label>
                      <input
                        class="bookie-input"
                        type="datetime-local"
                        value={{@controller.emDeadline}}
                        {{on "input" (fn @controller.updateField "emDeadline")}}
                      />
                      <span class="bookie-form-help">
                        Saved from your local timezone:
                        {{@controller.browserTimeZone}}
                      </span>
                    </div>
                    <div class="bookie-admin-edit-actions">
                      <button
                        class="btn btn-small btn-danger"
                        {{on "click" (fn @controller.deleteMatch match)}}
                        type="button"
                      >
                        Delete event
                      </button>
                      <button
                        class="btn btn-primary btn-small"
                        {{on "click" (fn @controller.saveMatch match)}}
                        type="button"
                      >
                        Save changes
                      </button>
                      <button
                        class="btn btn-small"
                        {{on "click" @controller.cancelEditingMatch}}
                        type="button"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                {{else}}
                  <div class="bookie-admin-card-layout">
                    <div class="bookie-admin-match-info">
                      <strong
                        class="bookie-admin-match-title"
                      >{{match.sport_icon}} {{match.title}}</strong>
                      {{#if match.competition}}
                        <span
                          class="bookie-admin-competition"
                        >{{match.competition}}</span>
                      {{/if}}
                      <span class="bookie-admin-odds">
                        Home
                        {{match.odds_home}}{{#if match.has_draw}}
                          · Draw
                          {{match.odds_draw}}{{/if}}
                        · Away
                        {{match.odds_away}}
                      </span>
                      <span class="bookie-admin-stats">
                        {{match.total_bets}}
                        bets ·
                        {{match.total_coins}}
                        {{@controller.currency}}
                        &nbsp;(🏠
                        {{match.bets_home}}{{#if match.has_draw}}
                          · ➡️
                          {{match.bets_draw}}{{/if}}
                        · ✈️
                        {{match.bets_away}})
                      </span>
                      <span class="bookie-admin-deadline">Deadline:
                        {{match.formattedDeadline}}</span>
                    </div>

                    <div class="bookie-admin-card-controls">
                      <button
                        class="bookie-admin-icon-btn"
                        type="button"
                        style="background: transparent; border: 1px solid var(--primary-low-mid, var(--primary-low)); border-radius: 2px; box-shadow: none; color: var(--primary-medium);"
                        title="Edit event"
                        {{on "click" (fn @controller.startEditingMatch match)}}
                      >
                        {{dIcon "pencil-alt"}}
                      </button>

                      <div class="bookie-admin-controls-separator"></div>

                      <div class="bookie-admin-actions">
                        <span class="bookie-settle-label">Settle as:</span>
                        <div class="bookie-admin-settle-buttons">
                          <button
                            class="bookie-admin-settle-btn bookie-admin-settle-btn-home"
                            type="button"
                            style="border-radius: 2px; font-weight: 400;"
                            {{on
                              "click"
                              (fn @controller.settleMatch match "home")
                            }}
                          >
                            Home wins
                          </button>
                          {{#if match.has_draw}}
                            <button
                              class="bookie-admin-settle-btn bookie-admin-settle-btn-draw"
                              type="button"
                              style="border-radius: 2px; font-weight: 400;"
                              {{on
                                "click"
                                (fn @controller.settleMatch match "draw")
                              }}
                            >
                              Draw
                            </button>
                          {{/if}}
                          <button
                            class="bookie-admin-settle-btn bookie-admin-settle-btn-away"
                            type="button"
                            style="border-radius: 2px; font-weight: 400;"
                            {{on
                              "click"
                              (fn @controller.settleMatch match "away")
                            }}
                          >
                            Away wins
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                {{/if}}
              </div>
            {{/each}}
          {{else}}
            <div class="bookie-empty">No open events to manage.</div>
          {{/if}}
        {{/if}}

        {{#if (eq @controller.adminSubTab "management")}}
          <div
            class="bookie-season-section bookie-season-section-first"
            style="margin-top: 0; padding-top: 0; border-top: 0;"
          >
            <h2 class="bookie-section-title">Admin tools</h2>
            <div class="bookie-season-card">
              <div class="bookie-season-info">
                <span class="bookie-season-label">Bulk grant</span>
                <span class="bookie-season-key">All players</span>
              </div>
              <p class="bookie-season-desc">
                Give every existing Bookie player the same amount of
                {{@controller.currency}}. Useful for compensation, resets or
                one-off boosts across the whole game.
              </p>
              <div class="bookie-admin-form bookie-admin-form-compact">
                <div class="bookie-form-row">
                  <label>Coins to grant</label>
                  <input
                    class="bookie-input"
                    type="number"
                    min="1"
                    step="1"
                    value={{@controller.grantAllAmount}}
                    placeholder="e.g. 100"
                    {{on "input" (fn @controller.updateField "grantAllAmount")}}
                  />
                </div>
                <div class="bookie-form-row">
                  <label>Reason (optional)</label>
                  <input
                    class="bookie-input"
                    type="text"
                    value={{@controller.grantAllReason}}
                    placeholder="e.g. Goodwill bonus after a bug"
                    {{on "input" (fn @controller.updateField "grantAllReason")}}
                  />
                  <span class="bookie-form-help">
                    This reason will be saved in every player's wallet log.
                  </span>
                </div>
                <button
                  class="btn btn-primary"
                  disabled={{@controller.grantAllLoading}}
                  {{on "click" @controller.grantAllPlayers}}
                  type="button"
                >
                  {{#if @controller.grantAllLoading}}
                    Granting coins…
                  {{else}}
                    Grant coins to all players
                  {{/if}}
                </button>
              </div>
            </div>
          </div>

          <div class="bookie-season-section">
            <h2 class="bookie-section-title">Period management</h2>
            <div class="bookie-season-card">
              {{#if @controller.closablePeriodLabel}}
                <div class="bookie-season-info">
                  <span class="bookie-season-label">Finished period</span>
                  <span
                    class="bookie-season-key"
                  >{{@controller.closablePeriodLabel}}</span>
                </div>

                {{#if @controller.closablePeriodClosed}}
                  <div class="bookie-season-closed-notice">
                    ✅ Period
                    {{@controller.closablePeriodLabel}}
                    is already closed.
                  </div>
                {{else}}
                  <p class="bookie-season-desc">
                    This snapshots the top 3 for the finished League Table
                    period so it appears under previous winners.
                  </p>
                  <button
                    class="btn btn-primary"
                    disabled={{@controller.periodClosing}}
                    {{on "click" @controller.closeCurrentPeriod}}
                    type="button"
                  >
                    {{#if @controller.periodClosing}}
                      Closing period…
                    {{else}}
                      Close period
                      {{@controller.closablePeriodLabel}}
                    {{/if}}
                  </button>
                {{/if}}
              {{else}}
                <p class="bookie-season-desc">
                  No finished period is waiting to be closed right now.
                </p>
              {{/if}}
            </div>

            <h2 class="bookie-section-title">Sprint management</h2>
            <div class="bookie-season-card">
              {{#if @controller.closableSprintLabel}}
                <div class="bookie-season-info">
                  <span class="bookie-season-label">Finished month</span>
                  <span
                    class="bookie-season-key"
                  >{{@controller.closableSprintLabel}}</span>
                </div>

                {{#if @controller.closableSprintClosed}}
                  <div class="bookie-season-closed-notice">
                    ✅ Sprint
                    {{@controller.closableSprintLabel}}
                    is already closed.
                  </div>
                {{else}}
                  <p class="bookie-season-desc">
                    This snapshots the top 3 for the finished Money Sprint month
                    so it appears under previous sprints.
                  </p>
                  <button
                    class="btn btn-primary"
                    disabled={{@controller.sprintClosing}}
                    {{on "click" @controller.closeCurrentSprint}}
                    type="button"
                  >
                    {{#if @controller.sprintClosing}}
                      Closing sprint…
                    {{else}}
                      Close sprint
                      {{@controller.closableSprintLabel}}
                    {{/if}}
                  </button>
                {{/if}}
              {{else}}
                <p class="bookie-season-desc">
                  No finished month is waiting to be closed right now.
                </p>
              {{/if}}
            </div>
          </div>

          {{! ── Season management ── }}
          <div class="bookie-season-section">
            <h2 class="bookie-section-title">Season management</h2>
            <div class="bookie-season-card">
              <div class="bookie-season-info">
                <span class="bookie-season-label">Current season</span>
                <span class="bookie-season-key">{{@controller.seasonKey}}</span>
              </div>
              {{#if @controller.seasonAlreadyClosed}}
                <div class="bookie-season-closed-notice">
                  ✅ Season
                  {{@controller.seasonKey}}
                  is closed. Standings have been saved. Start a new season by
                  clicking End Season at the end of next season.
                </div>
              {{else}}
                <p class="bookie-season-desc">
                  Closing the season saves the season top 3 by balance as
                  permanent winners and resets all wallet balances to the
                  starting amount. The League Table resets automatically every
                  two months.
                </p>
                <button
                  class="btn btn-danger bookie-end-season-btn"
                  disabled={{@controller.seasonLoading}}
                  {{on "click" @controller.endSeason}}
                  type="button"
                >
                  {{#if @controller.seasonLoading}}
                    Closing season…
                  {{else}}
                    🏁 End season
                    {{@controller.seasonKey}}
                  {{/if}}
                </button>
              {{/if}}
            </div>
          </div>
        {{/if}}

      </div>
    {{/if}}

  </div>
</template>
