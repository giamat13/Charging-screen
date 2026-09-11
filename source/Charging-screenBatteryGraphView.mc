import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Application.Storage;

// Battery level over a selectable time range (24h or 7d), from the background samples plus
// the live current reading as the last point. Green segments = charging.
class Charging_screenBatteryGraphView extends WatchUi.View {

    // Tap/select to cycle range. Kept on the view (not just the delegate) so it's still there
    // if the view is redrawn without the delegate changing anything.
    var mRangeDays as Number = 1;
    private const RANGE_OPTIONS_DAYS = [1, 7] as Array<Number>;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function cycleRange() as Void {
        var index = 0;
        for (var i = 0; i < RANGE_OPTIONS_DAYS.size(); i += 1) {
            if (RANGE_OPTIONS_DAYS[i] == mRangeDays) {
                index = i;
                break;
            }
        }
        mRangeDays = RANGE_OPTIONS_DAYS[(index + 1) % RANGE_OPTIONS_DAYS.size()];
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var tinyH = dc.getFontHeight(Graphics.FONT_XTINY);

        var windowSeconds = mRangeDays * 86400;
        var rangeLabel = (mRangeDays == 1) ? "24h" : (mRangeDays + "d");
        dc.drawText(centerX, 10, Graphics.FONT_SMALL, "Battery " + rangeLabel, Graphics.TEXT_JUSTIFY_CENTER);

        var now = Time.now().value();
        var stats = System.getSystemStats();
        var points = [] as Array<Array>;
        var log = Storage.getValue("batteryLog") as Array?;
        if (log != null) {
            for (var i = 0; i < log.size(); i += 1) {
                var p = log[i] as Array;
                if ((p[0] as Number) >= now - windowSeconds) {
                    points.add(p);
                }
            }
        }
        points.add([now, stats.battery, stats.charging]);

        // Inset the plot so it stays inside round screens.
        var left = width / 6;
        var right = width - width / 6;
        var top = height / 4;
        var bottom = height - height / 4;
        var plotW = right - left;
        var plotH = bottom - top;

        dc.setPenWidth(1);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(left, top, plotW, plotH);
        dc.drawLine(left, top + plotH / 2, right, top + plotH / 2);
        dc.drawText(left - 2, top - tinyH / 2, Graphics.FONT_XTINY, "100", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(left - 2, bottom - tinyH / 2, Graphics.FONT_XTINY, "0", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(left, bottom + 2, Graphics.FONT_XTINY, "-" + rangeLabel, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(right, bottom + 2, Graphics.FONT_XTINY, "now", Graphics.TEXT_JUSTIFY_RIGHT);

        if (points.size() < 2) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, top + plotH / 2 - tinyH, Graphics.FONT_XTINY, "Collecting data", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, top + plotH / 2, Graphics.FONT_XTINY, "(one sample per check)", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var windowStart = now - windowSeconds;
            dc.setPenWidth(2);
            var prevX = 0;
            var prevY = 0;
            var prevCharging = false;
            for (var i = 0; i < points.size(); i += 1) {
                var p = points[i];
                var charging = p[2] as Boolean;
                var x = left + ((((p[0] as Number) - windowStart) * plotW) / windowSeconds);
                var y = bottom - ((p[1] as Float) / 100.0 * plotH).toNumber();
                if (i > 0) {
                    dc.setColor(charging ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(prevX, prevY, x, y);

                    // Mark the plug-in / unplug transition itself, not just the color change,
                    // so a start/stop event is visible even at a glance on a 7-day-wide plot.
                    if (charging != prevCharging) {
                        dc.setColor(charging ? Graphics.COLOR_GREEN : Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
                        dc.fillCircle(x, y, 3);
                    }
                }
                prevX = x;
                prevY = y;
                prevCharging = charging;
            }
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, bottom + tinyH + 2, Graphics.FONT_XTINY, stats.battery.format("%.0f") + "% now", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, bottom + tinyH * 2 + 2, Graphics.FONT_XTINY, "Tap to change range", Graphics.TEXT_JUSTIFY_CENTER);
    }

}

// Battery-graph screen needs one interaction beyond simple page navigation (tap to cycle the
// displayed time range), so it keeps its own delegate instead of the generic PageDelegate.
class Charging_screenBatteryGraphDelegate extends WatchUi.BehaviorDelegate {

    private var mView as Charging_screenBatteryGraphView;

    function initialize(view as Charging_screenBatteryGraphView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onSelect() as Boolean {
        mView.cycleRange();
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt as ClickEvent) as Boolean {
        mView.cycleRange();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

}
