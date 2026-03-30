# discourse-bookie

A virtual betting plugin for [Discourse](https://www.discourse.org/). Members bet coins on football match outcomes — no real money involved. Built for [OnlineArsenal.com](https://onlinearsenal.com).

---

## Features

- **Match betting** — admins create matches with custom odds; members pick home/draw/away and stake coins
- **Two competitions running in parallel:**
  - 🏆 **League Table** — points-based, resets every two months; rewards picking accuracy and hot streaks
  - 💰 **Richest Gooner** — season-long coin ranking; rewards smart bankroll management
- **Weekly coin bonus** — 100 coins deposited every Monday to keep members active
- **Streak bonuses** — consecutive correct picks earn milestone rewards (+8 / +18 / +35)
- **Odds bonus** — longer shots earn extra League Table points when correct
- **BBCode widget** — embed live standings in any post with `[bookie-leaderboard]`
- **Podium UI** — gold/silver/bronze top-3 display with full table below
- **Rules tab** — built-in explanation of both competitions for new members
- **Admin panel** — create/settle/delete matches directly from `/bookie`
- **Automatic period close** — Discourse scheduled job snapshots League Table winners at the end of each period

---

## Requirements

- Discourse 3.2+
- Ruby 3.3+
- Ember 3.28+ (Octane)

---

## Installation

### 1. Clone into your Discourse plugins folder

```bash
cd /var/www/discourse/plugins
git clone https://github.com/YOUR-USERNAME/discourse-bookie.git
```

### 2. Run migrations

```bash
cd /var/www/discourse
bundle exec rails db:migrate
```

### 3. Restart Discourse

```bash
sudo systemctl restart discourse
```

The plugin is now active at `/bookie`.

---

## Updating

```bash
cd /var/www/discourse/plugins/discourse-bookie
git pull

cd /var/www/discourse
bundle exec rails assets:precompile
sudo systemctl restart discourse
```

---

## Configuration

Settings are available under **Admin → Settings → Plugins → Bookie**:

| Setting | Default | Description |
|---|---|---|
| `bookie_starting_balance` | `1000` | Coins given to new members |
| `bookie_weekly_bonus` | `100` | Coins deposited every Monday |
| `bookie_min_bet` | `10` | Minimum bet amount |
| `bookie_currency_name` | `Coins` | Display name for the currency |

---

## How it works

### League Table

Points are earned when a bet is settled:

| Event | Points |
|---|---|
| Placing any bet | +2 |
| Correct pick | +10 |
| Odds bonus (correct pick) | `round((odds − 1) × 4)` |
| 3-pick streak | +5 |
| 5-pick streak | +10 |
| 8-pick streak | +20 |

The table resets every two months: **Aug–Sep · Oct–Nov · Dec–Jan · Feb–Mar · Apr–May**. At the end of each period the top 3 are snapshotted and visible under Standings → previous period.

### Richest Gooner

Ranked by current coin balance. Runs all season. Only members who have placed at least one bet appear in the rankings.

### BBCode widget

Paste `[bookie-leaderboard]` anywhere in a post to embed a live standings widget showing the top 5 of both competitions.

---

## Development

```bash
# Start Rails
bin/rails server

# Start Ember CLI (separate terminal)
bin/ember-cli
```

Then visit `http://localhost:3000/bookie`.

---

## License

MIT
