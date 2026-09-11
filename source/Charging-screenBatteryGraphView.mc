import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Application.Storage;

// Battery level over the last 24h, from the hourly background samples plus the live
// current reading as the last point. Green segments = charging.
class Charging_screenBatteryGraphView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var tinyH = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.drawText(centerX, 10, Graphics.FONT_SMALL, "Battery 24h", Graphics.TEXT_JUSTIFY_CENTER);

        var now = Time.now().value();
        var stats = System.getSystemStats();
        var points = [] as Array<Array>;
        var log = Storage.getValue("batteryLog") as Array?;
        if (log != null) {
            for (var i = 0; i < log.size(); i += 1) {
                var p = log[i] as Array;
                if ((p[0] as Number) >= now - ChargeStats.LOG_WINDOW_SECONDS) {
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
        dc.drawText(left, bottom + 2, Graphics.FONT_XTINY, "-24h", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(right, bottom + 2, Graphics.FONT_XTINY, "now", Graphics.TEXT_JUSTIFY_RIGHT);

        if (points.size() < 2) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, top + plotH / 2 - tinyH, Graphics.FONT_XTINY, "Collecting data", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, top + plotH / 2, Graphics.FONT_XTINY, "(one sample per hour)", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var windowStart = now - ChargeStats.LOG_WINDOW_SECONDS;
        dc.setPenWidth(2);
        var prevX = 0;
        var prevY = 0;
        for (var i = 0; i < points.size(); i += 1) {
            var p = points[i];
            var x = left + ((((p[0] as Number) - windowStart) * plotW) / ChargeStats.LOG_WINDOW_SECONDS);
            var y = bottom - ((p[1] as Float) / 100.0 * plotH).toNumber();
            if (i > 0) {
                dc.setColor((p[2] as Boolean) ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(prevX, prevY, x, y);
            }
            prevX = x;
            prevY = y;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, bottom + tinyH + 2, Graphics.FONT_XTINY, stats.battery.format("%.0f") + "% now", Graphics.TEXT_JUSTIFY_CENTER);
    }

}

class Charging_screenBatteryGraphDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
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
