import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
import Toybox.Application.Storage;

// Main screen: the single most useful number at a glance (battery %, and either "time to
// full" while charging or "time left" while not) - everything else (rate, health, graphs,
// history) lives on the screens reachable by swiping forward, see Charging_screenDetailsView
// / Charging_screenHistoryView / Charging_screenBatteryGraphView.
class Charging_screenView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        // No need for fixed layout from Rez - everything is drawn manually in onUpdate
    }

    // Draws a horizontal battery icon (outline + cap + fill) centered at centerX, top at y.
    // Returns the total height consumed.
    private function drawBatteryIcon(dc as Dc, centerX as Number, y as Number, percent as Float) as Number {
        var barW = 90;
        var barH = 36;
        var capW = 6;
        var capH = 16;
        var pad = 3;

        var left = centerX - (barW + capW) / 2;
        var top = y;

        dc.setPenWidth(2);
        dc.setColor(ChargingUi.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(left, top, barW, barH, 4);
        dc.fillRoundedRectangle(left + barW, top + (barH - capH) / 2, capW, capH, 2);

        var fillW = ((barW - pad * 2) * (percent / 100.0)).toNumber();
        if (fillW > 0) {
            dc.setColor(ChargingUi.batteryColor(percent), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(left + pad, top + pad, fillW, barH - pad * 2, 2);
        }

        return barH;
    }

    // Draws the current time in the top-right corner.
    private function drawClock(dc as Dc, width as Number) as Void {
        var clockTime = System.getClockTime();
        var timeStr = clockTime.hour.format("%02d") + ":" + clockTime.min.format("%02d");
        dc.setColor(ChargingUi.TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 8, 4, Graphics.FONT_XTINY, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // One shared layout for every state this screen shows: icon, big %, one headline, one
    // subtitle - so every state (not charging / calculating / charging) reads the same way.
    private function drawStatus(dc as Dc, centerX as Number, height as Number,
            battery as Float, headline as String, subtitle as String, subColor as Graphics.ColorType) as Void {
        var bigH = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
        var medH = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var tinyH = dc.getFontHeight(Graphics.FONT_XTINY);
        var iconH = 36 + 10;

        var totalH = iconH + bigH + medH + tinyH + 6;
        var y = (height - totalH) / 2;

        y += drawBatteryIcon(dc, centerX, y, battery) + 10;

        dc.setColor(ChargingUi.batteryColor(battery), Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Graphics.FONT_NUMBER_MEDIUM, battery.format("%.0f") + "%", Graphics.TEXT_JUSTIFY_CENTER);
        y += bigH + 4;

        dc.setColor(ChargingUi.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Graphics.FONT_MEDIUM, headline, Graphics.TEXT_JUSTIFY_CENTER);
        y += medH + 2;

        dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Graphics.FONT_XTINY, subtitle, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(ChargingUi.TEXT_PRIMARY, ChargingUi.BG);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        var app = getApp();
        ChargingUi.drawPageDots(dc, width, ChargingUi.PAGE_MAIN, app.mIsCharging);
        drawClock(dc, width);

        var battery = app.mLastBattery;
        if (battery == null || app.mStartBattery == null || app.mStartTimeMs == null) {
            dc.setColor(ChargingUi.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height / 2, Graphics.FONT_SMALL, "Loading...", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (!app.mIsCharging) {
            var drainPerHour = Storage.getValue("avgDrainPerHour") as Float?;
            var subtitle = "Connect to charger";
            if (drainPerHour != null && (drainPerHour as Float) > 0) {
                subtitle = "~" + ChargingUi.formatDuration((battery as Float) / (drainPerHour as Float) * 60.0) + " left";
            }
            drawStatus(dc, centerX, height, battery as Float, "Not charging", subtitle, ChargingUi.TEXT_SECONDARY);
            return;
        }

        var elapsedMin = (System.getTimer() - (app.mStartTimeMs as Number)) / 60000.0;
        var deltaPercent = (battery as Float) - (app.mStartBattery as Float);

        if (elapsedMin < 0.5 || deltaPercent <= 0) {
            var subtitle = "Calculating...";
            var avgRate = app.mStoredAvgRate;
            if (avgRate != null && (avgRate as Float) > 0) {
                var estMinutes = ChargeStats.estimateMinutesToFull(battery as Float, avgRate as Float, 100.0);
                subtitle = "~" + ChargingUi.formatDuration(estMinutes) + " (usual pace)";
            }
            drawStatus(dc, centerX, height, battery as Float, "Charging", subtitle, ChargingUi.TEXT_SECONDARY);
            return;
        }

        var percentPerMin = deltaPercent / elapsedMin;
        var minutesToFull = ChargeStats.estimateMinutesToFull(battery as Float, percentPerMin, 100.0);
        var headline = ChargingUi.formatDuration(minutesToFull) + " to full";

        var isAnomaly = app.mSlowStreak >= app.ANOMALY_STREAK_THRESHOLD;
        var subtitle = isAnomaly ? "Slower than usual" : "Swipe for details";
        var subColor = isAnomaly ? ChargingUi.STATUS_BAD : ChargingUi.TEXT_SECONDARY;

        // A user-set goal ("X% by HH:MM") is more actionable than the generic swipe hint, so
        // it takes over the subtitle line - but a rate anomaly still takes priority, since
        // "check your cable" matters more than an on-track/behind readout.
        if (!isAnomaly && ChargeGoal.isSet()) {
            var goalPercent = ChargeGoal.getPercent() as Number;
            if ((battery as Float) >= goalPercent) {
                subtitle = "Goal reached: " + goalPercent + "%";
                subColor = ChargingUi.STATUS_GOOD;
            } else {
                var minutesNeeded = ChargeStats.estimateMinutesToFull(battery as Float, percentPerMin, goalPercent.toFloat());
                var minutesAvailable = ChargeGoal.minutesUntilGoalTime();
                if (minutesNeeded <= minutesAvailable) {
                    subtitle = "On track: " + goalPercent + "% by " + ChargeGoal.formatGoalTime();
                    subColor = ChargingUi.STATUS_GOOD;
                } else {
                    subtitle = "Won't reach " + goalPercent + "% by " + ChargeGoal.formatGoalTime();
                    subColor = ChargingUi.STATUS_ALERT;
                }
            }
        }

        drawStatus(dc, centerX, height, battery as Float, headline, subtitle, subColor);
    }

}
