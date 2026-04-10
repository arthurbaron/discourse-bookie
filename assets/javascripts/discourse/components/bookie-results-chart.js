import Component from "@ember/component";

function buildChartPoints(timeline) {
  if (!timeline?.length) {
    return [];
  }

  const chartLeft = 4;
  const chartRight = 96;
  const chartTop = 12;
  const chartBottom = 88;
  const chartHeight = chartBottom - chartTop;
  const values = timeline.map((item) => item.cumulative_points || 0);
  const min = Math.min(...values);
  const max = Math.max(...values);

  return timeline.map((item, index) => {
    const x =
      timeline.length === 1
        ? 50
        : chartLeft + (index / (timeline.length - 1)) * (chartRight - chartLeft);
    const value = item.cumulative_points || 0;
    const normalized = max === min ? 0.5 : (value - min) / (max - min);
    const y = chartBottom - normalized * chartHeight;
    const delta = Number(item.delta_points) || 0;
    const prefix = delta > 0 ? "+" : "";
    const label = item.label || `Event ${index + 1}`;
    const date = item.date
      ? new Date(item.date).toLocaleDateString("en-GB", {
          day: "numeric",
          month: "short",
        })
      : "";

    return {
      ...item,
      x: Number(x.toFixed(2)),
      y: Number(y.toFixed(2)),
      tooltip: `${label}\nBalance: ${value} coins\nEvent: ${prefix}${delta} coins${
        date ? `\n${date}` : ""
      }`,
    };
  });
}

function buildLinePath(points) {
  if (!points.length) {
    return "";
  }

  return points
    .map((point, index) => `${index === 0 ? "M" : "L"} ${point.x} ${point.y}`)
    .join(" ");
}

function buildAreaPath(points) {
  if (!points.length) {
    return "";
  }

  const baseY = 88;
  const linePath = buildLinePath(points);
  const first = points[0];
  const last = points[points.length - 1];
  return `${linePath} L ${last.x} ${baseY} L ${first.x} ${baseY} Z`;
}

export default class BookieResultsChart extends Component {
  points = null;

  get chartPoints() {
    return buildChartPoints(this.points || []);
  }

  get hasPoints() {
    return this.chartPoints.length > 0;
  }

  get linePath() {
    return buildLinePath(this.chartPoints);
  }

  get areaPath() {
    return buildAreaPath(this.chartPoints);
  }

  get gridLines() {
    return [12, 37.33, 62.66, 88];
  }
}
