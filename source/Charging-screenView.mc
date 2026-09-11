import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Timer;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Sensor;
import Toybox.Application.Storage;

// Application that runs only in the foreground (not in background). Enters it during charging,
// and measures charging rate: percentage per minute, minutes per percent, and estimated time to 100%.
class Charging_screenView extends WatchUi.View {

    private var mTimer as Timer.Timer?;

    // Measurement start values
    private var mStartTimeMs as Number?;
    private var mStartBattery as Float?;

    // Last measurement values
    private var mLastBattery as Float?;
    private var mIsCharging as Boolean = false;

    // Recent battery% samples for the sparkline, oldest first. Downsampled in place so it
    // keeps covering the whole session (which can span hours) within a fixed memory budget.
    private var mSamples as Array<Float> = [];
    private const MAX_SAMPLES = 60;

    // Average % per minute measured across previous completed sessions (Storage-backed),
    // used to show an estimate before the current session has enough data of its own.
    private var mStoredAvgRate as Float?;

    // Seconds between each measurement update
    private const UPDATE_INTERVAL_MS = 15000;

    // Charging tapers off as it approaches full (CC/CV curve): fast below TRICKLE_START,
    // then TRICKLE_MULTIPLIER times slower per percent above it.
    // ponytail: fixed heuristic, not a per-device learned curve - revisit if real logs show it's off.
    private const TRICKLE_START = 80.0;
    private const TRICKLE_MULTIPLIER = 2.5;

    // Consecutive ticks the session rate must stay below the average by ANOMALY_THRESHOLD_PCT
    // before flagging it, so a single noisy sample doesn't trigger a false "check your cable".
    private var mSlowStreak as Number = 0;
    private const ANOMALY_STREAK_THRESHOLD = 4;
    private const ANOMALY_THRESHOLD_PCT = -30.0;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        // No need for fixed layout from Rez - everything is drawn manually in onUpdate
    }

    // Starts/resets the measurement start point
    function resetStats() as Void {
        var stats = System.getSystemStats();
        mStartTimeMs = System.getTimer();
        mStartBattery = stats.battery;
        mLastBattery = stats.battery;
        mIsCharging = stats.charging;
        mSamples = [stats.battery as Float];
        mStoredAvgRate = Storage.getValue("avgPercentPerMin") as Float?;
        WatchUi.requestUpdate();
    }

    // Called when this View is brought to the foreground.
    function onShow() as Void {
        resetStats();

        mTimer = new Timer.Timer();
        mTimer.start(method(:onTimerTick), UPDATE_INTERVAL_MS, true);
    }

    // Persists this session's result (via the shared ChargeStats module, also used by the
    // background check) then resets the measurement start point for the new (idle) state.
    private function finishSession() as Void {
        var elapsedMin = (System.getTimer() - (mStartTimeMs as Number)) / 60000.0;
        var deltaPercent = (mLastBattery as Float) - (mStartBattery as Float);
        ChargeStats.recordSession(deltaPercent, elapsedMin);
    }

    function onTimerTick() as Void {
        var stats = System.getSystemStats();
        var wasCharging = mIsCharging;
        mLastBattery = stats.battery;
        mIsCharging = stats.charging;

        if (wasCharging && !mIsCharging) {
            finishSession();
            resetStats();
        } else if (mIsCharging) {
            mSamples.add(stats.battery as Float);
            if (mSamples.size() > MAX_SAMPLES) {
                var downsampled = [] as Array<Float>;
                for (var i = 0; i < mSamples.size(); i += 2) {
                    downsampled.add(mSamples[i]);
                }
                mSamples = downsampled;
            }

            var elapsedMin = (System.getTimer() - (mStartTimeMs as Number)) / 60000.0;
            var deltaPercent = (stats.battery as Float) - (mStartBattery as Float);
            if (mStoredAvgRate != null && (mStoredAvgRate as Float) > 0 && elapsedMin >= 0.5 && deltaPercent > 0) {
                var rate = deltaPercent / elapsedMin;
                var diffPct = (rate - (mStoredAvgRate as Float)) / (mStoredAvgRate as Float) * 100.0;
                mSlowStreak = (diffPct <= ANOMALY_THRESHOLD_PCT) ? mSlowStreak + 1 : 0;
            } else {
                mSlowStreak = 0;
            }
        }

        WatchUi.requestUpdate();
    }

    // Called when this View is removed from the screen - stops the timer
    // because the application is not supposed to run in the background.
    function onHide() as Void {
        if (mTimer != null) {
            mTimer.stop();
            mTimer = null;
        }
    }

    // Color for the battery level: red when low, yellow mid, green when high/full
    private function batteryColor(percent as Float) as Graphics.ColorType {
        if (percent >= 80) {
            return Graphics.COLOR_GREEN;
        } else if (percent >= 30) {
            return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_RED;
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
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(left, top, barW, barH, 4);
        dc.fillRoundedRectangle(left + barW, top + (barH - capH) / 2, capW, capH, 2);

        var fillW = ((barW - pad * 2) * (percent / 100.0)).toNumber();
        if (fillW > 0) {
            dc.setColor(batteryColor(percent), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(left + pad, top + pad, fillW, barH - pad * 2, 2);
        }

        return barH;
    }

    // Charging slows down as it approaches full - a plain linear extrapolation of the
    // current rate underestimates time to 100% once past TRICKLE_START. Model it as two
    // linear phases instead of one.
    private function estimateMinutesToFull(currentPercent as Float, minPerPercent as Float) as Float {
        if (currentPercent >= TRICKLE_START) {
            return (100.0 - currentPercent) * minPerPercent * TRICKLE_MULTIPLIER;
        }
        var fastMinutes = (TRICKLE_START - currentPercent) * minPerPercent;
        var trickleMinutes = (100.0 - TRICKLE_START) * minPerPercent * TRICKLE_MULTIPLIER;
        return fastMinutes + trickleMinutes;
    }

    private function formatMinutesToFull(minutesToFull as Float) as String {
        if (minutesToFull < 0 || minutesToFull > 1440) {
            return "Time to 100%: unknown";
        }
        var totalMinutes = minutesToFull.toNumber();
        return "Time to 100%: " + (totalMinutes / 60) + "h " + (totalMinutes % 60) + "m";
    }

    // Draws the current time in the top-right corner.
    private function drawClock(dc as Dc, width as Number) as Void {
        var clockTime = System.getClockTime();
        var timeStr = clockTime.hour.format("%02d") + ":" + clockTime.min.format("%02d");
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 8, 4, Graphics.FONT_XTINY, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Draws the device temperature in the top-left corner, on devices with a thermometer.
    private function drawTemperature(dc as Dc) as Void {
        var temperature = Sensor.getInfo().temperature;
        if (temperature == null) {
            return;
        }
        dc.setColor((temperature as Number) >= 40 ? Graphics.COLOR_ORANGE : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, 4, Graphics.FONT_XTINY, temperature.format("%.0f") + "°C", Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Thin polyline of this session's battery% samples, showing the charging trend at a glance.
    private function drawSparkline(dc as Dc, centerX as Number, y as Number, w as Number, h as Number) as Void {
        if (mSamples.size() < 2) {
            return;
        }
        var minV = mSamples[0];
        var maxV = mSamples[0];
        for (var i = 1; i < mSamples.size(); i += 1) {
            if (mSamples[i] < minV) { minV = mSamples[i]; }
            if (mSamples[i] > maxV) { maxV = mSamples[i]; }
        }
        var range = maxV - minV;
        if (range < 1.0) {
            range = 1.0;
        }

        var left = centerX - w / 2;
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        var prevX = 0;
        var prevY = 0;
        for (var i = 0; i < mSamples.size(); i += 1) {
            var px = left + (w * i / (mSamples.size() - 1));
            var py = y + h - ((mSamples[i] - minV) / range * h).toNumber();
            if (i > 0) {
                dc.drawLine(prevX, prevY, px, py);
            }
            prevX = px;
            prevY = py;
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        drawClock(dc, width);
        drawTemperature(dc);

        if (mLastBattery == null || mStartBattery == null || mStartTimeMs == null) {
            dc.drawText(centerX, height / 2, Graphics.FONT_SMALL, "Loading...", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (!mIsCharging) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height / 2 - 30, Graphics.FONT_MEDIUM, "Not charging", Graphics.TEXT_JUSTIFY_CENTER);
            drawBatteryIcon(dc, centerX, height / 2, mLastBattery as Float);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height / 2 + 45, Graphics.FONT_XTINY, "Connect watch to charger", Graphics.TEXT_JUSTIFY_CENTER);

            // Estimate based on the drain rate the background check has been learning from
            // this watch's actual usage (see ChargeStats.recordDrainSample) - only available
            // once it's had a couple of not-charging hours to sample.
            var drainPerHour = Storage.getValue("avgDrainPerHour") as Float?;
            if (drainPerHour != null && drainPerHour > 0) {
                var totalMin = ((mLastBattery as Float) / drainPerHour * 60).toNumber();
                dc.drawText(centerX, height / 2 + 65, Graphics.FONT_XTINY,
                    "~" + (totalMin / 60) + "h " + (totalMin % 60) + "m left (your pace)", Graphics.TEXT_JUSTIFY_CENTER);
            }
            return;
        }

        var elapsedMs = System.getTimer() - (mStartTimeMs as Number);
        var elapsedMin = elapsedMs / 60000.0;
        var deltaPercent = (mLastBattery as Float) - (mStartBattery as Float);
        var battColor = batteryColor(mLastBattery as Float);

        // Exact font heights from the device
        var bigH   = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
        var smallH = dc.getFontHeight(Graphics.FONT_TINY);
        var tinyH  = dc.getFontHeight(Graphics.FONT_XTINY);
        var iconH  = 36 + 10; // icon height + spacing below it

        if (elapsedMin < 0.5 || deltaPercent <= 0) {
            // rows: icon, big%, calculating (+ optional stored-average estimate), measured — center the block
            var haveAvg = mStoredAvgRate != null && (mStoredAvgRate as Float) > 0;
            var totalH = iconH + bigH + tinyH + (haveAvg ? tinyH : 0) + tinyH;
            var y = (height - totalH) / 2;

            y += drawBatteryIcon(dc, centerX, y, mLastBattery as Float) + 10;

            dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_NUMBER_MEDIUM, (mLastBattery as Float).format("%.0f") + "%", Graphics.TEXT_JUSTIFY_CENTER);
            y += bigH;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Calculating charging rate...", Graphics.TEXT_JUSTIFY_CENTER);
            y += tinyH;
            if (haveAvg) {
                var avgMinPerPercent = 1.0 / (mStoredAvgRate as Float);
                var estMinutes = estimateMinutesToFull(mLastBattery as Float, avgMinPerPercent);
                dc.drawText(centerX, y, Graphics.FONT_XTINY, "~" + formatMinutesToFull(estMinutes) + " (avg)", Graphics.TEXT_JUSTIFY_CENTER);
                y += tinyH;
            }
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Measured " + elapsedMin.format("%.1f") + " min", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var percentPerMin = deltaPercent / elapsedMin;
        var minPerPercent = 1.0 / percentPerMin;
        var minutesToFull = estimateMinutesToFull(mLastBattery as Float, minPerPercent);

        var haveAvgRate = mStoredAvgRate != null && (mStoredAvgRate as Float) > 0;
        var diffPct = haveAvgRate ? (percentPerMin - (mStoredAvgRate as Float)) / (mStoredAvgRate as Float) * 100.0 : 0.0;
        var isAnomaly = mSlowStreak >= ANOMALY_STREAK_THRESHOLD;

        // rows: icon, sparkline, big%, %/min, min/%, gained, time, health/anomaly, measured — center the block
        var sparkH = 16;
        var totalH = iconH + sparkH + bigH + smallH + smallH + smallH + smallH + (haveAvgRate ? tinyH : 0) + tinyH;
        var y = (height - totalH) / 2;

        y += drawBatteryIcon(dc, centerX, y, mLastBattery as Float) + 6;
        drawSparkline(dc, centerX, y, 110, sparkH);
        y += sparkH + 4;

        dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Graphics.FONT_NUMBER_MEDIUM, (mLastBattery as Float).format("%.0f") + "%", Graphics.TEXT_JUSTIFY_CENTER);
        y += bigH;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Graphics.FONT_TINY, percentPerMin.format("%.2f") + "% per minute", Graphics.TEXT_JUSTIFY_CENTER);
        y += smallH;
        dc.drawText(centerX, y, Graphics.FONT_TINY, minPerPercent.format("%.1f") + " min per percent", Graphics.TEXT_JUSTIFY_CENTER);
        y += smallH;
        dc.drawText(centerX, y, Graphics.FONT_TINY, "+" + deltaPercent.format("%.1f") + "% since start", Graphics.TEXT_JUSTIFY_CENTER);
        y += smallH;

        dc.drawText(centerX, y, Graphics.FONT_TINY, formatMinutesToFull(minutesToFull), Graphics.TEXT_JUSTIFY_CENTER);
        y += smallH;

        if (isAnomaly) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Slower than usual - check cable/charger", Graphics.TEXT_JUSTIFY_CENTER);
            y += tinyH;
        } else if (haveAvgRate) {
            dc.setColor(diffPct >= 0 ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            var dir = diffPct >= 0 ? "faster" : "slower";
            dc.drawText(centerX, y, Graphics.FONT_XTINY, diffPct.abs().format("%.0f") + "% " + dir + " than usual", Graphics.TEXT_JUSTIFY_CENTER);
            y += tinyH;
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Graphics.FONT_XTINY, "Measured " + elapsedMin.format("%.0f") + " min (hold for menu to reset)", Graphics.TEXT_JUSTIFY_CENTER);
    }

}
