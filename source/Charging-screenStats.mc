import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application.Storage;
import Toybox.Application.Properties;

// Shared session-recording logic used by both the foreground timer (fine-grained, 15s
// resolution while the app is open) and the hourly background check (coarse resolution,
// catches sessions that happen while the app is closed) - both paths feed the same
// avg/best/history/baseline/curve/hour data so the health trend covers the device's whole
// lifetime, not just what happened while someone was watching the app.
(:background)
module ChargeStats {

    // Number of completed sessions used to lock in the "baseline" rate for the health
    // trend. Locked once and never overwritten, so later degradation has something fixed
    // to compare against.
    const BASELINE_SESSIONS = 5;

    // How often the background check (Charging_screenServiceDelegate) runs by default - 15
    // minutes is the common interval for this kind of battery-history widget, fine-grained
    // enough to be useful without noticeably affecting battery life. User-adjustable from the
    // Garmin Connect app on the phone (resources/settings/properties.xml), not on the watch.
    const DEFAULT_INTERVAL_MINUTES = 15;

    // Battery graph: how far back the log is kept, and a hard cap on entry count regardless
    // of the check interval, so storage-limited older devices are protected too.
    const LOG_WINDOW_SECONDS = 7 * 86400;
    const MAX_LOG_ENTRIES = 500;

    // Per-device charging curve: rate is learned separately for each 10%-wide battery bucket
    // (0 = 0-10%, ... 9 = 90-100%) instead of assuming one fixed "fast then trickle" shape.
    // ponytail: a session spanning several buckets contributes its one blended average rate to
    // every bucket it touches (not a true instantaneous curve) - it sharpens as narrower
    // sessions accumulate. Good enough without per-sample timing data from the background path.
    const BUCKET_COUNT = 10;
    const BUCKET_WIDTH = 10.0;

    // Fallback shape (used per-bucket only until that bucket has learned data of its own):
    // fast below TRICKLE_START_BUCKET, then TRICKLE_MULTIPLIER times slower per percent.
    const TRICKLE_START_BUCKET = 8; // 80%
    const TRICKLE_MULTIPLIER = 2.5;

    function isBackgroundEnabled() as Boolean {
        var enabled = Properties.getValue("backgroundEnabled") as Boolean?;
        return (enabled == null) ? true : enabled;
    }

    function getIntervalSeconds() as Number {
        var minutes = Properties.getValue("backgroundIntervalMinutes") as Number?;
        minutes = (minutes == null) ? DEFAULT_INTERVAL_MINUTES : minutes;
        return minutes * 60;
    }

    function recordSession(startBattery as Float, endBattery as Float, elapsedMin as Float) as Void {
        var deltaPercent = endBattery - startBattery;
        if (elapsedMin < 0.5 || deltaPercent <= 0) {
            return;
        }
        var rate = deltaPercent / elapsedMin;
        var now = Time.now().value();

        var prevAvg = Storage.getValue("avgPercentPerMin") as Float?;
        var newAvg = (prevAvg == null) ? rate : (prevAvg * 0.7 + rate * 0.3);
        Storage.setValue("avgPercentPerMin", newAvg);

        var prevBest = Storage.getValue("bestPercentPerMin") as Float?;
        if (prevBest == null || rate > prevBest) {
            Storage.setValue("bestPercentPerMin", rate);
        }

        var sessionCount = Storage.getValue("sessionCount") as Number?;
        sessionCount = (sessionCount == null) ? 1 : sessionCount + 1;
        Storage.setValue("sessionCount", sessionCount);
        if (sessionCount == BASELINE_SESSIONS) {
            Storage.setValue("baselineRate", newAvg);
        }

        var history = Storage.getValue("chargeHistory") as Array?;
        if (history == null) {
            history = [];
        }
        history.add({
            "endTime" => now,
            "durationMin" => elapsedMin,
            "percentGained" => deltaPercent,
        });
        while (history.size() > 10) {
            history.remove(history[0]);
        }
        Storage.setValue("chargeHistory", history);

        updateChargeCurve(startBattery, endBattery, rate);
        recordStartHour(now - (elapsedMin * 60).toNumber());
    }

    function updateChargeCurve(startBattery as Float, endBattery as Float, rate as Float) as Void {
        var curve = Storage.getValue("chargeCurve") as Array?;
        if (curve == null) {
            curve = new[BUCKET_COUNT];
        }
        var startBucket = (startBattery / BUCKET_WIDTH).toNumber();
        var endBucket = ((endBattery - 0.01) / BUCKET_WIDTH).toNumber();
        if (startBucket < 0) { startBucket = 0; }
        if (endBucket > BUCKET_COUNT - 1) { endBucket = BUCKET_COUNT - 1; }

        for (var i = startBucket; i <= endBucket; i += 1) {
            var prev = curve[i] as Float?;
            curve[i] = (prev == null) ? rate : (prev * 0.7 + rate * 0.3);
        }
        Storage.setValue("chargeCurve", curve);
    }

    // Minutes to reach targetPercent (100% by default, i.e. full) from currentPercent, using
    // the learned per-bucket curve where available and falling back to the fixed fast/trickle
    // shape (scaled by this session's own rate) for buckets that haven't been learned yet.
    function estimateMinutesToFull(currentPercent as Float, fallbackRatePerMin as Float, targetPercent as Float) as Float {
        if (currentPercent >= targetPercent) {
            return 0.0;
        }

        var curve = Storage.getValue("chargeCurve") as Array?;
        var totalMin = 0.0;
        var pos = currentPercent;
        var bucket = (pos / BUCKET_WIDTH).toNumber();
        if (bucket > BUCKET_COUNT - 1) { bucket = BUCKET_COUNT - 1; }

        while (pos < targetPercent && bucket < BUCKET_COUNT) {
            var bucketEnd = (bucket + 1) * BUCKET_WIDTH;
            if (bucketEnd > targetPercent) { bucketEnd = targetPercent; }
            var segPercent = bucketEnd - pos;

            var learnedRate = (curve != null) ? (curve[bucket] as Float?) : null;
            var rate = (learnedRate != null && (learnedRate as Float) > 0)
                ? (learnedRate as Float)
                : (bucket >= TRICKLE_START_BUCKET ? fallbackRatePerMin / TRICKLE_MULTIPLIER : fallbackRatePerMin);

            totalMin += segPercent / rate;
            pos = bucketEnd;
            bucket += 1;
        }
        return totalMin;
    }

    // Histogram of the hour-of-day (0-23, local time) sessions tend to start at, so the
    // history screen can show "usually starts charging around 22:00" - a fixed-size counter
    // array that accumulates for the device's whole lifetime, not just the last few sessions.
    function recordStartHour(startTimeSec as Number) as Void {
        var hour = Gregorian.info(new Time.Moment(startTimeSec), Time.FORMAT_SHORT).hour;
        var counts = Storage.getValue("startHourCounts") as Array?;
        if (counts == null) {
            counts = new[24];
        }
        var current = counts[hour] as Number?;
        counts[hour] = (current == null) ? 1 : current + 1;
        Storage.setValue("startHourCounts", counts);
    }

    // A 0-100 "how's my battery doing" score, derived from how the recent (EMA) charge rate
    // compares to the baseline locked in from the first BASELINE_SESSIONS - the OS-reported
    // battery % on these devices is already capacity-normalized, so rate drift is the only
    // degradation signal available here. Null until a baseline exists (see recordSession).
    function getHealthScore() as Number? {
        var baseline = DemoData.getValue("baselineRate") as Float?;
        var recent = DemoData.getValue("avgPercentPerMin") as Float?;
        if (baseline == null || recent == null || (baseline as Float) <= 0) {
            return null;
        }
        var changePct = ((recent as Float) - (baseline as Float)) / (baseline as Float) * 100.0;
        var score = (100.0 + changePct).toNumber();
        if (score > 100) { score = 100; }
        if (score < 0) { score = 0; }
        return score;
    }

    function healthLabel(score as Number) as String {
        if (score >= 95) { return "Excellent"; }
        if (score >= 85) { return "Good"; }
        if (score >= 70) { return "Fair"; }
        return "Degraded";
    }

    function healthColor(score as Number) as Graphics.ColorType {
        if (score >= 85) { return ChargingUi.STATUS_GOOD; }
        if (score >= 70) { return ChargingUi.STATUS_MID; }
        return ChargingUi.STATUS_ALERT;
    }

    // The most common charge-start hour, or null until there's enough data to be meaningful.
    function getUsualStartHour() as Number? {
        var counts = DemoData.getValue("startHourCounts") as Array?;
        if (counts == null) {
            return null;
        }
        var bestHour = null;
        var bestCount = 0;
        var total = 0;
        for (var h = 0; h < 24; h += 1) {
            var c = counts[h] as Number?;
            if (c == null) { c = 0; }
            total += c;
            if (c > bestCount) {
                bestCount = c;
                bestHour = h;
            }
        }
        return (total >= 3) ? bestHour : null;
    }

    // Called every background tick with the current battery% and charging state. When two
    // consecutive not-charging samples exist, updates an EMA of drain %/hour so the "Not
    // charging" screen can estimate time left based on the user's actual usage pattern.
    function recordDrainSample(currentBattery as Float, isCharging as Boolean) as Void {
        var now = Time.now().value();
        var lastBattery = Storage.getValue("bgLastBattery") as Float?;
        var lastTime = Storage.getValue("bgLastSampleTime") as Number?;
        var lastCharging = Storage.getValue("bgLastCharging") as Boolean?;

        if (!isCharging && lastCharging != null && !lastCharging && lastBattery != null && lastTime != null) {
            var elapsedHours = (now - lastTime) / 3600.0;
            var drop = lastBattery - currentBattery;
            if (elapsedHours >= 0.1 && drop > 0) {
                var rate = drop / elapsedHours;
                var prevDrain = Storage.getValue("avgDrainPerHour") as Float?;
                var newDrain = (prevDrain == null) ? rate : (prevDrain * 0.7 + rate * 0.3);
                Storage.setValue("avgDrainPerHour", newDrain);
            }
        }

        Storage.setValue("bgLastBattery", currentBattery);
        Storage.setValue("bgLastSampleTime", now);
        Storage.setValue("bgLastCharging", isCharging);

        // Rolling log for the battery graph, as compact [time, battery, charging] triples,
        // bounded by both age (LOG_WINDOW_SECONDS) and count (MAX_LOG_ENTRIES).
        var log = Storage.getValue("batteryLog") as Array?;
        if (log == null) {
            log = [];
        }
        log.add([now, currentBattery, isCharging]);
        while (log.size() > 0 && ((log[0] as Array)[0] as Number) < now - LOG_WINDOW_SECONDS) {
            log.remove(log[0]);
        }
        while (log.size() > MAX_LOG_ENTRIES) {
            log.remove(log[0]);
        }
        Storage.setValue("batteryLog", log);
    }

}
