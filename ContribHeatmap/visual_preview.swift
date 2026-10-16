import Cocoa
import WebKit

let username = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Jeetchavan02"

// Fetch data
let url = URL(string: "https://github-contributions-api.jogruber.de/v4/\(username)?y=last")!
var daysData: [(date: String, count: Int, level: Int)] = []

let sema = DispatchSemaphore(value: 0)
let task = URLSession.shared.dataTask(with: url) { data, _, _ in
    defer { sema.signal() }
    guard let data = data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let contributions = json["contributions"] as? [[String: Any]] else { return }
    
    for c in contributions {
        if let d = c["date"] as? String, let cnt = c["count"] as? Int {
            daysData.append((d, cnt, c["level"] as? Int ?? 0))
        }
    }
}
task.resume()
_ = sema.wait(timeout: .now() + 5)

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 100, y: 100, width: 840, height: 520),
    styleMask: [.titled, .closable, .miniaturizable],
    backing: .buffered,
    defer: false
)
window.title = "GitHub Heatmap Widget — Live macOS Preview (\(username))"
window.center()

let webView = WKWebView(frame: window.contentView!.bounds)
webView.autoresizingMask = [.width, .height]
window.contentView?.addSubview(webView)

let total = daysData.reduce(0) { $0 + $1.count }

var jsonItems = daysData.map { "{\"date\":\"\($0.date)\",\"count\":\($0.count)}" }.joined(separator: ",")

let html = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body {
    background: #0d1117;
    color: #e6edf3;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    padding: 30px;
    margin: 0;
    user-select: none;
  }
  .title { font-size: 20px; font-weight: 700; margin-bottom: 25px; display: flex; align-items: center; gap: 10px; }
  .badge { background: rgba(35, 134, 54, 0.2); color: #3fb950; padding: 4px 10px; border-radius: 12px; font-size: 13px; font-weight: 600; }
  .cards { display: flex; gap: 30px; flex-wrap: wrap; }
  
  /* Widget simulated container (Liquid Glass macOS 27 look) */
  .widget-card {
    background: rgba(22, 27, 34, 0.7);
    border: 1px solid rgba(240, 246, 252, 0.1);
    border-radius: 22px;
    padding: 16px;
    box-shadow: 0 16px 36px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.1);
    backdrop-filter: blur(20px);
    display: flex;
    flex-direction: column;
    box-sizing: border-box;
  }
  .widget-card.small { width: 170px; height: 170px; }
  .widget-card.medium { width: 360px; height: 170px; }

  .widget-header { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 8px; }
  .user { font-size: 11px; font-weight: 700; color: #f0f6fc; }
  .stat { font-size: 10px; color: #8b949e; }
  
  .grid { display: flex; gap: 3px; flex: 1; align-items: center; justify-content: center; }
  .col { display: flex; flex-direction: column; gap: 3px; }
  .cell {
    width: 10px;
    height: 10px;
    border-radius: 2px;
    background: #161b22;
  }
  .cell.lvl-0 { background: #161b22; }
  .cell.lvl-1 { background: #0e4429; }
  .cell.lvl-2 { background: #006d32; }
  .cell.lvl-3 { background: #26a641; }
  .cell.lvl-4 { background: #39d353; }
  .cell.future { visibility: hidden; }

  .legend { margin-top: 30px; display: flex; gap: 8px; align-items: center; font-size: 11px; color: #8b949e; }
  .legend-box { width: 10px; height: 10px; border-radius: 2px; }
</style>
</head>
<body>
  <div class="title">
    <span>GitHub Contribution Heatmap</span>
    <span class="badge">Live macOS Preview: @\(username)</span>
    <span style="font-size: 13px; color: #8b949e; margin-left: auto;">Total: \(total) contributions</span>
  </div>

  <div class="cards">
    <!-- Small Widget -->
    <div>
      <div style="font-size: 12px; font-weight: 600; color: #8b949e; margin-bottom: 8px;">SMALL WIDGET (.systemSmall — 9 Weeks)</div>
      <div class="widget-card small">
        <div class="widget-header">
          <div class="user">@\(username)</div>
          <div class="stat" id="small-stat"></div>
        </div>
        <div class="grid" id="small-grid"></div>
      </div>
    </div>

    <!-- Medium Widget -->
    <div>
      <div style="font-size: 12px; font-weight: 600; color: #8b949e; margin-bottom: 8px;">MEDIUM WIDGET (.systemMedium — 20 Weeks)</div>
      <div class="widget-card medium">
        <div class="widget-header">
          <div class="user">@\(username)</div>
          <div class="stat" id="med-stat"></div>
        </div>
        <div class="grid" id="med-grid"></div>
      </div>
    </div>
  </div>

  <div class="legend">
    <span>Less</span>
    <div class="legend-box lvl-0 cell"></div>
    <div class="legend-box lvl-1 cell"></div>
    <div class="legend-box lvl-2 cell"></div>
    <div class="legend-box lvl-3 cell"></div>
    <div class="legend-box lvl-4 cell"></div>
    <span>More</span>
  </div>

<script>
  const rawDays = [\(jsonItems)];
  const map = {};
  rawDays.forEach(d => { map[d.date] = d.count; });

  function getSunday(d) {
    const date = new Date(d);
    const day = date.getDay();
    const diff = date.getDate() - day;
    return new Date(date.setDate(diff));
  }

  function buildWeeks(weekCount) {
    const today = new Date();
    today.setHours(0,0,0,0);
    const thisSunday = getSunday(today);
    const startSunday = new Date(thisSunday);
    startSunday.setDate(startSunday.getDate() - (weekCount - 1) * 7);

    // Compute non-zero quartile thresholds
    const windowCounts = [];
    for (let w = 0; w < weekCount; w++) {
      for (let d = 0; d < 7; d++) {
        const cur = new Date(startSunday);
        cur.setDate(cur.getDate() + (w * 7 + d));
        const key = cur.toISOString().split('T')[0];
        const cnt = map[key] || 0;
        if (cur <= today && cnt > 0) windowCounts.push(cnt);
      }
    }
    windowCounts.sort((a,b) => a - b);
    const n = windowCounts.length;
    function p(q) {
      if (!n) return 0;
      return windowCounts[Math.max(0, Math.min(n - 1, Math.ceil(q * n) - 1))];
    }
    const p25 = p(0.25), p50 = p(0.50), p75 = p(0.75);

    function getLevel(cnt) {
      if (cnt <= 0) return 0;
      if (cnt <= p25) return 1;
      if (cnt <= p50) return 2;
      if (cnt <= p75) return 3;
      return 4;
    }

    let weeksHtml = '';
    let totalWindow = 0;
    for (let w = 0; w < weekCount; w++) {
      weeksHtml += '<div class="col">';
      for (let d = 0; d < 7; d++) {
        const cur = new Date(startSunday);
        cur.setDate(cur.getDate() + (w * 7 + d));
        const key = cur.toISOString().split('T')[0];
        const isFuture = cur > today;
        const cnt = map[key] || 0;
        if (!isFuture) totalWindow += cnt;
        const lvl = isFuture ? 'future' : 'lvl-' + getLevel(cnt);
        weeksHtml += `<div class="cell ${lvl}" title="${key}: ${cnt} contributions"></div>`;
      }
      weeksHtml += '</div>';
    }
    return { html: weeksHtml, total: totalWindow };
  }

  const small = buildWeeks(9);
  document.getElementById('small-grid').innerHTML = small.html;
  document.getElementById('small-stat').innerText = small.total + ' contribs';

  const med = buildWeeks(20);
  document.getElementById('med-grid').innerHTML = med.html;
  document.getElementById('med-stat').innerText = med.total + ' in 20 wks';
</script>
</body>
</html>
"""

webView.loadHTMLString(html, baseURL: nil)
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
