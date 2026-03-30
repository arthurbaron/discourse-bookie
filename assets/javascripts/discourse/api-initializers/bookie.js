import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

export default apiInitializer("0.11.1", (api) => {
  // ── Navigation link ─────────────────────────────────────────────────────────
  // Adds a "Bookie" link to the top navigation bar
  api.addNavigationBarItem({
    name: "bookie",
    displayName: "Bookie",
    href: "/bookie",
    title: "Virtual match betting",
    icon: "shield",
  });

  // ── [bookie-leaderboard] BBCode decorator ───────────────────────────────────
  api.decorateCooked(
    (elem) => {
      const el = elem instanceof Element ? elem : elem[0];
      if (!el) return;

      el.querySelectorAll("p, div").forEach((node) => {
        if (!node.textContent.includes("[bookie-leaderboard]")) return;
        if (node.innerHTML.includes("blw-widget")) return;

        const widget = document.createElement("div");
        widget.className = "blw-widget";
        widget.innerHTML = '<div class="bookie-widget-loading">Loading standings...</div>';

        node.parentNode.insertBefore(widget, node);
        node.remove();

        ajax("/bookie/leaderboard.json")
          .then((data) => {
            const leagueTable  = data.league_table   || [];
            const richest      = data.richest_gooner  || [];
            const currency     = data.currency        || "coins";
            const periodLabel  = data.current_period_label || "";

            function renderRows(entries, valueKey, unit) {
              if (!entries.length) {
                return '<div class="bookie-widget-empty">No data yet.</div>';
              }
              const medals = ["🥇", "🥈", "🥉"];
              return `<ol class="blw-list">
                ${entries.slice(0, 5).map((u, i) => `
                  <li class="blw-row ${i < 3 ? "blw-top rank-" + (i + 1) : ""}">
                    <span class="blw-rank">${medals[i] || "#" + u.rank}</span>
                    <span class="blw-name">${u.username}</span>
                    <span class="blw-val">${u[valueKey]} ${unit}</span>
                  </li>`).join("")}
              </ol>`;
            }

            function activateTab(w, tab) {
              w.querySelectorAll(".blw-tab").forEach((t) => t.classList.remove("active"));
              w.querySelector(`.blw-tab[data-tab="${tab}"]`).classList.add("active");
              const content = w.querySelector(".blw-content");
              if (tab === "league") {
                content.innerHTML = renderRows(leagueTable, "points", "pts");
              } else {
                content.innerHTML = renderRows(richest, "balance", currency);
              }
            }

            widget.innerHTML = `
              <div class="blw-header">
                <strong class="blw-title">Bookie Standings</strong>
                <a href="/bookie" class="blw-full-link">Full standings →</a>
              </div>
              <div class="blw-tabs">
                <button class="blw-tab active" data-tab="league">League Table</button>
                <button class="blw-tab" data-tab="richest">Richest Gooner</button>
              </div>
              ${periodLabel ? `<div class="blw-period">${periodLabel}</div>` : ""}
              <div class="blw-content"></div>
            `;

            // Wire up tab clicks
            widget.querySelectorAll(".blw-tab").forEach((btn) => {
              btn.addEventListener("click", () => activateTab(widget, btn.dataset.tab));
            });

            // Show league table by default
            activateTab(widget, "league");
          })
          .catch(() => {
            widget.innerHTML = '<div class="bookie-widget-empty">Could not load standings.</div>';
          });
      });
    },
    { id: "discourse-bookie-leaderboard-widget" }
  );

  // ── [bookie] BBCode decorator ────────────────────────────────────────────────
  // Renders a mini widget in posts where an author types [bookie]
  api.decorateCooked(
    (elem) => {
      const el = elem instanceof Element ? elem : elem[0];
      if (!el) return;

      // Find any paragraphs containing "[bookie]"
      el.querySelectorAll("p, div").forEach((node) => {
        if (!node.textContent.includes("[bookie]")) return;
        if (node.innerHTML.includes("bookie-widget")) return; // already rendered

        // Replace [bookie] with a loading widget
        const placeholder = document.createElement("div");
        placeholder.className = "bookie-widget";
        placeholder.innerHTML =
          '<div class="bookie-widget-loading">Loading matches...</div>';

        // Replace the paragraph content
        const parent = node.parentNode;
        parent.insertBefore(placeholder, node);
        node.remove();

        // Fetch open matches and render them
        ajax("/bookie/matches.json")
          .then((data) => {
            const matches = data.matches || [];
            const currency = data.currency || "coins";

            if (matches.length === 0) {
              placeholder.innerHTML =
                '<div class="bookie-widget-empty">No open matches right now.</div>';
              return;
            }

            placeholder.innerHTML = `
              <div class="bookie-widget-header">
                <span class="bookie-widget-icon">🎲</span>
                <strong>Open bets this week</strong>
                <a href="/bookie" class="bookie-widget-link">View all →</a>
              </div>
              <ul class="bookie-widget-list">
                ${matches
                  .slice(0, 3)
                  .map(
                    (m) => `
                  <li class="bookie-widget-match">
                    <span class="bookie-widget-teams">
                      ${m.home_team} vs ${m.away_team}
                    </span>
                    <span class="bookie-widget-odds">
                      ${m.home_team} ${m.odds_home} · Draw ${m.odds_draw} · ${m.away_team} ${m.odds_away}
                    </span>
                    ${
                      m.user_bet
                        ? `<span class="bookie-widget-bet-placed">✓ Bet placed (${m.user_bet.amount} ${currency})</span>`
                        : `<a href="/bookie" class="btn btn-small bookie-widget-bet-btn">Place bet</a>`
                    }
                  </li>
                `
                  )
                  .join("")}
              </ul>
              ${
                matches.length > 3
                  ? `<a href="/bookie" class="bookie-widget-more">+${matches.length - 3} more matches →</a>`
                  : ""
              }
            `;
          })
          .catch(() => {
            placeholder.innerHTML =
              '<div class="bookie-widget-empty">Could not load matches.</div>';
          });
      });
    },
    { id: "discourse-bookie-widget" }
  );
});
