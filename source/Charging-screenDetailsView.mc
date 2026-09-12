import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
import Toybox.Sensor;

// Everything about the current charging session that doesn't fit on the glanceable main
// screen: rate, sparkline trend, health-vs-usual comparison, temperature, elapsed time.
// Only reachable by swiping forward from the main screen while actively charging.
class Charging_screenDetailsView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    // Thin polyline of this session's battery% samples, showing the charging trend at a glance.
    private function drawSparkline(dc as Dc, centerX as Number, y as Number, w as Number, h as Number, samples as Array<Float>) as Void {
        if (samples.size() < 2) {
            return;
        }
        var minV = samples[0];
        var maxV = samples[0];
        for (var i = 1; i < samples.size(); i += 1) {
            if (samples[i] < minV) { minV = samples[i]; }
            if (samples[i] > maxV) { maxV = samples[i]; }
        }
        var range = maxV - minV;
        if (range < 1.0) {
            range = 1.0;
        }

        var left = centerX - w / 2;
        dc.setPenWidth(2);
        dc.setColor(ChargingUi.STATUS_GOOD_DIM, Graphics.COLOR_TRANSPARENT);
        var prevX = 0;
        var prevY = 0;
        for (var i = 0; i < samples.size(); i += 1) {
            var px = left + (w * i / (samples.size() - 1));
            var py = y + h - ((samples[i] - minV) / range * h).toNumber();
            if (i > 0) {
                dc.drawLine(prevX, prevY, px, py);
            }
            prevX = px;
            prevY = py;
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(ChargingUi.TEXT_PRIMARY, ChargingUi.BG);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var rowH = dc.getFontHeight(Graphics.FONT_TINY);
        var tinyH = dc.getFontHeight(Graphics.FONT_XTINY);

        var app = getApp();
        var y = ChargingUi.drawHeader(dc, width, ChargingUi.PAGE_DETAILS, "Details", app.mIsCharging) + 10;

        if (!app.mIsCharging || app.mLastBattery == null) {
            dc.setColor(ChargingUi.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height / 2, Graphics.FONT_XTINY, "No active session", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            ChargingUi.drawFooterHint(dc, width, height, "Swipe back for status");
            return;
        }

        var elapsedMin = (System.getTimer() - (app.mStartTimeMs as Number)) / 60000.0;
        var deltaPercent = (app.mLastBattery as Float) - (app.mStartBattery as Float);

        var sparkH = 30;
        drawSparkline(dc, centerX, y, width - 40, sparkH, app.mSamples);
        y += sparkH + 10;

        if (elapsedMin >= 0.5 && deltaPercent > 0) {
            var percentPerMin = deltaPercent / elapsedMin;
            var minPerPercent = 1.0 / percentPerMin;

            dc.setColor(ChargingUi.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_TINY, percentPerMin.format("%.2f") + "%/min", Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
            dc.drawText(centerX, y, Graphics.FONT_TINY, minPerPercent.format("%.1f") + " min/%  ·  +" + deltaPercent.format("%.1f") + "%", Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH + 6;

            var avgRate = app.mStoredAvgRate;
            if (avgRate != null && (avgRate as Float) > 0) {
                var diffPct = (percentPerMin - (avgRate as Float)) / (avgRate as Float) * 100.0;
                var isAnomaly = app.mSlowStreak >= app.ANOMALY_STREAK_THRESHOLD;
                if (isAnomaly) {
                    dc.setColor(ChargingUi.STATUS_BAD, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(centerX, y, Graphics.FONT_XTINY, "Slower than usual - check cable/charger", Graphics.TEXT_JUSTIFY_CENTER);
                } else {
                    dc.setColor(diffPct >= 0 ? ChargingUi.STATUS_GOOD : ChargingUi.STATUS_MID, Graphics.COLOR_TRANSPARENT);
                    var dir = diffPct >= 0 ? "faster" : "slower";
                    dc.drawText(centerX, y, Graphics.FONT_XTINY, diffPct.abs().format("%.0f") + "% " + dir + " than usual", Graphics.TEXT_JUSTIFY_CENTER);
                }
                y += tinyH + 6;
            }
        } else {
            dc.setColor(ChargingUi.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Calculating...", Graphics.TEXT_JUSTIFY_CENTER);
            y += tinyH + 6;
        }

        var temperature = Sensor.getInfo().temperature;
        if (temperature != null) {
            dc.setColor(ChargingUi.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, temperature.format("%.0f") + "°C", Graphics.TEXT_JUSTIFY_CENTER);
        }

        ChargingUi.drawFooterHint(dc, width, height, "Measured " + elapsedMin.format("%.0f") + " min  ·  swipe for history");
    }

}
