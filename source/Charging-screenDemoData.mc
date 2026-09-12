import Toybox.Lang;
import Toybox.Time;
import Toybox.Application.Storage;
import Toybox.Application.Properties;

// Off by default. When the "Demo data" setting is turned on (from the Garmin Connect app),
// every screen shows a fixed, plausible charging scenario instead of the device's real state
// - for taking screenshots / checking layouts without waiting for an actual charge.
(:background)
module DemoData {

    function isEnabled() as Boolean {
        var enabled = Properties.getValue("demoDataEnabled") as Boolean?;
        return (enabled == null) ? false : enabled;
    }

    // Fixed live-session scenario for the Main/Details screens: charging, 18 minutes in,
    // 45% -> 63%, with a matching sparkline.
    const BATTERY = 63.0;
    const START_BATTERY = 45.0;
    const ELAPSED_MIN = 18.0;
    const SAMPLES = [45.0, 48.0, 52.0, 55.0, 58.0, 61.0, 63.0] as Array<Float>;

    // Drop-in replacement for Storage.getValue(key) wherever a screen reads persisted
    // stats/history for display - returns canned data while demo mode is on, the real
    // stored value otherwise. Recording (ChargeStats.recordSession/recordDrainSample) is
    // untouched, so real background tracking keeps running underneath.
    function getValue(key as String) as Object? {
        if (!isEnabled()) {
            return Storage.getValue(key);
        }

        var now = Time.now().value();
        switch (key) {
            case "bestPercentPerMin":
                return 1.85;
            case "avgPercentPerMin":
                return 1.42;
            case "baselineRate":
                return 1.55;
            case "sessionCount":
                return 12;
            case "installTime":
                return now - 60 * 86400;
            case "startHourCounts":
                var counts = new[24];
                counts[22] = 9;
                counts[23] = 3;
                counts[7] = 2;
                return counts;
            case "chargeHistory":
                return [
                    { "endTime" => now - 4 * 86400, "durationMin" => 95.0, "percentGained" => 58.0 },
                    { "endTime" => now - 3 * 86400, "durationMin" => 110.0, "percentGained" => 64.0 },
                    { "endTime" => now - 2 * 86400, "durationMin" => 88.0, "percentGained" => 52.0 },
                    { "endTime" => now - 1 * 86400, "durationMin" => 102.0, "percentGained" => 61.0 },
                ];
            case "batteryLog":
                var log = [] as Array<Array>;
                for (var i = 24; i >= 0; i -= 1) {
                    var t = now - i * 3600;
                    var charging = i <= 6;
                    var level = charging ? (40 + (6 - i) * 10) : (85 - (24 - i) * 2);
                    if (level > 100) { level = 100; }
                    if (level < 5) { level = 5; }
                    log.add([t, level.toFloat(), charging]);
                }
                return log;
            default:
                return Storage.getValue(key);
        }
    }

}
