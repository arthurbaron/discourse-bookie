import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import loadScript from "discourse/lib/load-script";

export default class BookieResultsChart extends Component {
  points = null;
  currency = "coins";
  _chart = null;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this._scheduleRender();
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    this._scheduleRender();
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this._resetChart();
  }

  _scheduleRender() {
    schedule("afterRender", () => this._renderChart());
  }

  _renderChart() {
    const canvas = this.element?.querySelector(".bookie-results-chart-canvas");
    const points = this.points || [];

    if (!canvas || !points.length) {
      this._resetChart();
      return;
    }

    const context = canvas.getContext("2d");
    const styles = getComputedStyle(this.element);
    const primary = styles.getPropertyValue("--primary").trim() || "#ffffff";
    const medium = styles.getPropertyValue("--primary-medium").trim() || "#a0a0a0";
    const low = styles.getPropertyValue("--primary-low").trim() || "#3a3a3a";
    const tertiary = styles.getPropertyValue("--tertiary").trim() || "#08c";

    const labels = points.map((point, index) => `${index + 1}`);
    const data = points.map((point) => point.cumulative_points || 0);
    const details = points.map((point) => ({
      label: point.label,
      deltaPoints: point.delta_points,
      cumulativePoints: point.cumulative_points,
      date: point.date,
    }));

    this._resetChart();

    if (!this.element) {
      return;
    }

    loadScript("/javascripts/Chart.min.js")
      .then(() => {
        if (!this.element || !window.Chart) {
          return;
        }

        this._chart = new window.Chart(context, {
          type: "line",
          data: {
            labels,
            datasets: [
              {
                data,
                fill: true,
                borderColor: tertiary,
                backgroundColor: `${tertiary}33`,
                borderWidth: 2,
                tension: 0.35,
                pointRadius: 3,
                pointHoverRadius: 4,
                pointBackgroundColor: tertiary,
                pointBorderColor: tertiary,
              },
            ],
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: {
              duration: 0,
            },
            plugins: {
              legend: {
                display: false,
              },
              tooltip: {
                displayColors: false,
                callbacks: {
                  title: (items) => details[items[0].dataIndex]?.label || "",
                  label: (item) => {
                    const detail = details[item.dataIndex];
                    return `Balance: ${detail?.cumulativePoints || 0} ${this.currency}`;
                  },
                  afterLabel: (item) => {
                    const detail = details[item.dataIndex];
                    const delta = detail?.deltaPoints || 0;
                    const prefix = delta > 0 ? "+" : "";
                    return `Event: ${prefix}${delta} ${this.currency}`;
                  },
                  footer: (items) => {
                    const detail = details[items[0].dataIndex];
                    if (!detail?.date) {
                      return "";
                    }

                    return new Date(detail.date).toLocaleDateString("en-GB", {
                      day: "numeric",
                      month: "short",
                    });
                  },
                },
              },
            },
            scales: {
              x: {
                grid: {
                  display: false,
                },
                ticks: {
                  color: medium,
                  maxTicksLimit: 6,
                },
                border: {
                  color: low,
                },
              },
              y: {
                beginAtZero: true,
                ticks: {
                  color: medium,
                  callback: (value) => `${value}`,
                },
                grid: {
                  color: low,
                },
                border: {
                  color: low,
                },
              },
            },
          },
        });
      })
      .catch(() => {
        this._resetChart();
      });
  }

  _resetChart() {
    if (this._chart) {
      this._chart.destroy();
      this._chart = null;
    }
  }
}
