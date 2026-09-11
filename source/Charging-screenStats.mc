import Toybox.Lang;
import Toybox.Time;
import Toybox.Application.Storage;

// Shared session-recording logic used by both the foreground timer (fine-grained, 15s
// resolution while the app is open) and the hourly background check (coarse resolution,
// catches sessions that happen while the app is closed) - both paths feed the same
// avg/best/history/baseline data so the health trend covers the device's whole lifetime.
(:background)
module ChargeStats {

    // Number of completed sessions used to lock in the "baseline" rate for the health
    // trend. Locked once and never overwritten, so later degradation has something fixed
    // to compare against.
    const BASELINE_SESSIONS = 5;

    // How often the background check (Charging_screenServiceDelegate) is allowed to run.
    const BACKGROUND_INTERVAL_SECONDS = 3600;

    // How far back the battery graph looks.
    const LOG_WINDOW_SECONDS = 86400;

    function recordSession(deltaPercent as Float, elapsedMin as Float) as Void {
        if (elapsedMin < 0.5 || deltaPercent <= 0) {
            return;
        }
        var rate = deltaPercent / elapsedMin;

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
            "endTime" => Time.now().value(),
            "durationMin" => elapsedMin,
            "percentGained" => deltaPercent,
        });
        while (history.size() > 10) {
            history.remove(history[0]);
        }
        Storage.setValue("chargeHistory", history);
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

        // Rolling 24h log for the battery graph, as compact [time, battery, charging] triples.
        var log = Storage.getValue("batteryLog") as Array?;
        if (log == null) {
            log = [];
        }
        log.add([now, currentBattery, isCharging]);
        while (log.size() > 0 && ((log[0] as Array)[0] as Number) < now - LOG_WINDOW_SECONDS) {
            log.remove(log[0]);
        }
        Storage.setValue("batteryLog", log);
    }

}
