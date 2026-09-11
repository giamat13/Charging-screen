import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application.Storage;

// Shows the last few completed charging sessions (swipe/next-page from the main screen).
class Charging_screenHistoryView extends WatchUi.View {

    private const MAX_LISTED = 4;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    // Small bar chart of per-session charge rate (%/min), oldest to newest, left to right.
    private function drawRateBars(dc as Dc, centerX as Number, y as Number, w as Number, h as Number, history as Array) as Void {
        var rates = [] as Array<Float>;
        for (var i = 0; i < history.size(); i += 1) {
            var entry = history[i] as Dictionary;
            var durationMin = entry["durationMin"] as Float;
            rates.add(durationMin > 0 ? (entry["percentGained"] as Float) / durationMin : 0.0);
        }

        var maxRate = rates[0];
        for (var i = 1; i < rates.size(); i += 1) {
            if (rates[i] > maxRate) { maxRate = rates[i]; }
        }
        if (maxRate <= 0) {
            maxRate = 1.0;
        }

        var left = centerX - w / 2;
        var barGap = 4;
        var barW = (w - barGap * (rates.size() - 1)) / rates.size();
        if (barW < 2) {
            barW = 2;
        }

        for (var i = 0; i < rates.size(); i += 1) {
            var barH = (h * rates[i] / maxRate).toNumber();
            if (barH < 2) {
                barH = 2;
            }
            var x = left + i * (barW + barGap);
            dc.setColor(i == rates.size() - 1 ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y + h - barH, barW, barH);
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var centerX = width / 2;
        var rowH = dc.getFontHeight(Graphics.FONT_TINY);

        var history = Storage.getValue("chargeHistory") as Array?;
        var best = Storage.getValue("bestPercentPerMin") as Float?;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 10, Graphics.FONT_SMALL, "Charge History", Graphics.TEXT_JUSTIFY_CENTER);

        var y = 10 + rowH + 8;
        if (best != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Best: " + (best as Float).format("%.2f") + "%/min", Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
        }

        var usualHour = ChargeStats.getUsualStartHour();
        if (usualHour != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Usually starts ~" + (usualHour as Number).format("%02d") + ":00", Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
        }

        // Health trend: how the recent (EMA) charge rate compares to the rate baseline
        // locked in from the first few sessions - an indirect signal of battery degradation
        // (see ChargeStats.BASELINE_SESSIONS).
        var baseline = Storage.getValue("baselineRate") as Float?;
        var recent = Storage.getValue("avgPercentPerMin") as Float?;
        if (baseline != null && recent != null && baseline > 0) {
            var changePct = (recent - baseline) / baseline * 100.0;
            var installTime = Storage.getValue("installTime") as Number?;
            var sinceStr = "";
            if (installTime != null) {
                var days = (Time.now().value() - installTime) / 86400;
                sinceStr = " (" + days + "d)";
            }
            dc.setColor(changePct >= -5.0 ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Rate " + changePct.format("%.0f") + "% vs baseline" + sinceStr, Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
        } else {
            var sessionCount = Storage.getValue("sessionCount") as Number?;
            sessionCount = (sessionCount == null) ? 0 : sessionCount;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Baseline: " + sessionCount + "/" + ChargeStats.BASELINE_SESSIONS + " sessions", Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
        }
        y += 4;

        if (history == null || history.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "No completed sessions yet", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var barH = 36;
        drawRateBars(dc, centerX, y, width - 40, barH, history as Array);
        y += barH + 12;

        // Most recent first, limited to what comfortably fits below the chart.
        var listed = 0;
        var i = history.size() - 1;
        while (i >= 0 && listed < MAX_LISTED) {
            var entry = history[i] as Dictionary;
            var info = Gregorian.info(new Time.Moment(entry["endTime"] as Number), Time.FORMAT_SHORT);
            var dateStr = info.month.format("%02d") + "/" + info.day.format("%02d") + " " + info.hour.format("%02d") + ":" + info.min.format("%02d");

            var durationMin = (entry["durationMin"] as Float).toNumber();
            var durationStr = (durationMin / 60) + "h" + (durationMin % 60).format("%02d") + "m";

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY,
                dateStr + "  " + durationStr + "  +" + (entry["percentGained"] as Float).format("%.0f") + "%",
                Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
            i -= 1;
            listed += 1;
        }
    }

}
