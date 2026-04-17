import Component from "@ember/component";
import { scheduleOnce } from "@ember/runloop";
import loadScript from "discourse/lib/load-script";

const CHART_JS_CDN =
  "https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js";

// Reads a CSS custom property from :root (e.g. "--tertiary")
function cssVar(name, fallback) {
  const val = getComputedStyle(document.documentElement)
    .getPropertyValue(name)
    .trim();
  return val || fallback;
}

// Converts any CSS color string to rgba(r,g,b,alpha).
// Handles #rrggbb, #rgb, rgb(...), and hsl(...) (via temporary DOM element).
function toRgba(color, alpha) {
  if (!color) return `rgba(0,0,0,${alpha})`;

  // Hex shorthand → full hex
  if (/^#[0-9a-f]{3}$/i.test(color)) {
    color = `#${color[1]}${color[1]}${color[2]}${color[2]}${color[3]}${color[3]}`;
  }

  if (/^#[0-9a-f]{6}$/i.test(color)) {
    const r = parseInt(color.slice(1, 3), 16);
    const g = parseInt(color.slice(3, 5), 16);
    const b = parseInt(color.slice(5, 7), 16);
    return `rgba(${r},${g},${b},${alpha})`;
  }

  if (color.startsWith("rgb(")) {
    return color.replace("rgb(", "rgba(").replace(")", `,${alpha})`);
  }

  if (color.startsWith("rgba(")) {
    // Replace existing alpha
    return color.replace(/,\s*[\d.]+\)$/, `,${alpha})`);
  }

  // Fallback: use canvas to parse (handles hsl, named colors, etc.)
  try {
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = 1;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = color;
    ctx.fillRect(0, 0, 1, 1);
    const [r, g, b] = ctx.getImageData(0, 0, 1, 1).data;
    return `rgba(${r},${g},${b},${alpha})`;
  } catch (_e) {
    return `rgba(0,0,0,${alpha})`;
  }
}

function isMobileViewport() {
  return window.matchMedia?.("(max-width: 600px)")?.matches;
}

function formatCompactNumber(value) {
  return new Intl.NumberFormat("en", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(Number(value) || 0);
}

export default class BookieResultsChart extends Component {
  _chart = null;

  get hasPoints() {
    return (this.points || []).length > 0;
  }

  // ── Lifecycle ──────────────────────────────────────────

  didInsertElement() {
    super.didInsertElement(...arguments);
    scheduleOnce("afterRender", this, "_initChart");
  }

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);
    scheduleOnce("afterRender", this, "_updateChart");
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this._destroyChart();
  }

  // ── Chart helpers ──────────────────────────────────────

  _destroyChart() {
    if (this._chart) {
      this._chart.destroy();
      this._chart = null;
    }
  }

  _resolveColors() {
    const accent = cssVar("--tertiary", "#4c72ff");
    const danger = cssVar("--danger", "#e45735");
    const textMuted = cssVar("--primary-medium", "#9a9a9a");
    const gridColor = toRgba(cssVar("--primary", "#222"), 0.07);
    return { accent, danger, textMuted, gridColor };
  }

  _buildGradient(ctx, chartArea, accentColor) {
    if (!chartArea) return toRgba(accentColor, 0.15);
    const gradient = ctx.createLinearGradient(
      0,
      chartArea.top,
      0,
      chartArea.bottom
    );
    gradient.addColorStop(0, toRgba(accentColor, 0.3));
    gradient.addColorStop(1, toRgba(accentColor, 0.0));
    return gradient;
  }

  _buildConfig(colors) {
    const timeline = this.points || [];
    const { accent, danger, textMuted, gridColor } = colors;

    return {
      type: "line",
      data: {
        labels: timeline.map(
          (p, i) =>
            p.label ||
            (p.date
              ? new Date(p.date).toLocaleDateString("en-GB", {
                  day: "numeric",
                  month: "short",
                })
              : `Event ${i + 1}`)
        ),
        datasets: [
          {
            data: timeline.map((p) => p.cumulative_points || 0),
            borderColor: accent,
            borderWidth: 2,
            // Gradient fill is applied after chart creation via _applyGradient
            backgroundColor: toRgba(accent, 0.15),
            fill: true,
            tension: 0.3,
            pointRadius: 5,
            pointHoverRadius: 7,
            pointBackgroundColor: timeline.map((p) =>
              p.won ? accent : danger
            ),
            pointBorderColor: cssVar("--secondary", "#fff"),
            pointBorderWidth: 1.5,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 400 },
        interaction: {
          mode: "index",
          intersect: false,
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: cssVar("--secondary", "#fff"),
            titleColor: cssVar("--primary", "#222"),
            bodyColor: cssVar("--primary-medium", "#9a9a9a"),
            borderColor: cssVar("--primary-low", "#e0e0e0"),
            borderWidth: 1,
            padding: 10,
            callbacks: {
              title: (items) => items[0]?.label || "",
              label: (item) => {
                const pt = timeline[item.dataIndex];
                if (!pt) return "";
                const delta = Number(pt.delta_points) || 0;
                const prefix = delta > 0 ? "+" : "";
                const result = pt.won ? "✓ Correct" : "✗ Wrong";
                const currency = this.currency || "coins";
                return [
                  `${result}  ·  ${prefix}${delta} ${currency}`,
                  `Balance: ${item.parsed.y} ${currency}`,
                ];
              },
            },
          },
        },
        scales: {
          x: {
            display: false,
          },
          y: {
            display: true,
            position: "right",
            grid: {
              color: gridColor,
              drawBorder: false,
            },
            border: { display: false },
            ticks: {
              maxTicksLimit: 4,
              color: textMuted,
              font: { size: 11 },
              callback: (val) =>
                isMobileViewport()
                  ? formatCompactNumber(val)
                  : `${val} ${this.currency || "coins"}`,
            },
          },
        },
      },
    };
  }

  _applyGradient() {
    if (!this._chart) return;
    const { ctx, chartArea, data } = this._chart;
    if (!chartArea) return;
    const colors = this._resolveColors();
    data.datasets[0].backgroundColor = this._buildGradient(
      ctx,
      chartArea,
      colors.accent
    );
    this._chart.update("none"); // no animation for gradient re-apply
  }

  async _initChart() {
    if (!this.element) return;

    const canvas = this.element.querySelector("canvas");
    if (!canvas) return;

    if (!window.Chart) {
      try {
        await loadScript(CHART_JS_CDN);
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error("[bookie] Failed to load Chart.js", e);
        return;
      }
    }

    if (!this.element) return; // component may have been destroyed while loading

    this._destroyChart();

    const colors = this._resolveColors();
    this._chart = new window.Chart(canvas, this._buildConfig(colors));

    // Apply gradient after first render (needs chartArea to be set)
    scheduleOnce("afterRender", this, "_applyGradient");
  }

  _updateChart() {
    if (!this._chart) {
      this._initChart();
      return;
    }

    const timeline = this.points || [];
    const colors = this._resolveColors();
    const { accent, danger } = colors;

    this._chart.data.labels = timeline.map(
      (p, i) =>
        p.label ||
        (p.date
          ? new Date(p.date).toLocaleDateString("en-GB", {
              day: "numeric",
              month: "short",
            })
          : `Event ${i + 1}`)
    );

    const ds = this._chart.data.datasets[0];
    ds.data = timeline.map((p) => p.cumulative_points || 0);
    ds.pointBackgroundColor = timeline.map((p) => (p.won ? accent : danger));
    ds.borderColor = accent;

    this._chart.update();
    this._applyGradient();
  }
}
