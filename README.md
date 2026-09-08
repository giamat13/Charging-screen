# Charging Screen

A Garmin Connect IQ watch application that provides real-time charging statistics and battery monitoring while your device is charging.

## Overview

**Charging Screen** is a foreground-only watchapp designed to display detailed charging information during the battery charging process. It calculates and visualizes charging rates, estimated time to full battery, and current battery percentage with an intuitive visual interface.

## Key Features

### Real-Time Charging Monitoring
- Displays current battery percentage with color-coded status (red/yellow/green)
- Continuously updates charging statistics every 15 seconds
- Visual battery icon with fill level representation

### Charging Rate Analysis
Once charging measurements stabilize (after ~30 seconds or 1% battery gain):
- **% per minute** — Charging speed in percentage points per minute
- **Minutes per percent** — Time required to charge each percentage point
- **Time to 100%** — Estimated time until full battery charge (displayed as hours and minutes)

### Smart Display States

#### Detecting Charge
Displays "Not charging" message when device is not connected to charger.

#### Measuring Phase
During initial measurement:
- Shows battery percentage
- Displays "Calculating charging rate..."
- Updates elapsed measurement time (in minutes)
- Waits for at least 30 seconds and 1% battery increase before computing rates

#### Active Charging
Once stable measurements are available:
- Large battery percentage (color-coded)
- Charging statistics (% per minute, min per percent)
- Estimated time to full charge
- Measurement duration for reference

### Battery Color Indicator
- **🟢 Green** — Battery ≥80% (Good condition)
- **🟡 Yellow** — Battery 30–79% (Mid-range)
- **🔴 Red** — Battery <30% (Low)

## Technical Specifications

### Platform
- **Target Platform:** Garmin Connect IQ (API Level 3.0+)
- **Application Type:** Watch App (foreground)
- **Language:** Monkey C

### Device Compatibility
Supports **150+ Garmin devices**, including:
- **Fenix Series** — fenix5/6/7/8 and Pro variants
- **Epix Series** — epix2 and epix2 Pro
- **fēnix® Chronos**
- **Edge Cycling Computers** — Edge 520 Plus through Edge 1050
- **Instinct Series** — Instinct 2, Instinct 3, Instinct Crossover AMOLED
- **Venu Series** — Venu, Venu 2, Venu 3, Venu SQ2/M
- **Descent Series** — Descent Mk1/Mk2/G1/G2 and Mk3 variants
- **Legacy and Special Editions** — MARQ, Legacy Hero, Montana, Oregon, Rino

### Code Structure
```
source/
├── Charging-screenApp.mc        # Application entry point and lifecycle
├── Charging-screenView.mc       # Main UI rendering and charging logic
├── Charging-screenDelegate.mc   # Input handling and menu navigation
└── Charging-screenMenuDelegate  # Menu item selection handling

resources/
├── layouts/layout.xml           # Layout resources
├── drawables/                   # Icons and graphics
└── strings/strings.xml          # User-facing text strings
```

### Key Implementation Details

#### Measurement System
- **Update Interval:** 15 seconds (UPDATE_INTERVAL_MS = 15000ms)
- **Minimum Measurement Time:** 0.5 minutes (30 seconds)
- **Minimum Battery Change:** 1% (prevents division errors)
- **Maximum Time Estimate:** 1440 minutes (24 hours)

#### Drawing System
- Custom battery icon rendering using rounded rectangles
- Dynamic text sizing based on available screen space
- Vertical centering for optimal display on various device screens
- Manual layout (no XML-based layout system)

#### Timer Management
- Foreground-only execution (no background service)
- Timer automatically starts when view appears (onShow)
- Timer automatically stops when view is hidden (onHide)
- Prevents battery drain from background polling

## Usage

### Starting the App
1. Download "Charging Screen" from the Garmin Connect IQ Store
2. Launch the app on your Garmin device
3. Connect your watch to its charger
4. App will automatically display charging statistics

### Resetting Measurements
Press and hold the menu button to reset all charging statistics and start a new measurement cycle.

### Exiting the App
- The app is foreground-only and will close when you switch away or open another app
- Always monitor your device while charging

## User Interface

### Screen Layout (Charging State)
```
┌─────────────────────────────────┐
│                                 │
│        [Battery Icon]           │
│           75%                   │
│     1.25% per minute            │
│     0.8 min per percent         │
│  Time to 100%: 0h 20m           │
│                                 │
│   Measured 15 min (hold menu)   │
└─────────────────────────────────┘
```

### Screen Layout (Not Charging)
```
┌─────────────────────────────────┐
│                                 │
│      Not charging               │
│        [Battery Icon]           │
│                                 │
│    Connect watch to charger     │
└─────────────────────────────────┘
```

## Development

### Prerequisites
- Garmin ConnectIQ SDK
- Monkey C compiler
- Visual Studio Code with Monkey C extension (recommended)

### Building
```bash
monkeyc -I ${ConnectIQ_SDK}/bin/api.jar \
        -r ${ConnectIQ_SDK}/bin/resources.jar \
        -z 1 -o bin/Charging-screen.prg \
        -d ~/Library/Application\ Support/Garmin/ConnectIQ/Devices \
        source/
```

### Testing
- Use the Garmin ConnectIQ Simulator to test on various device profiles
- Simulate charging by modifying System.getSystemStats().battery values
- Test on multiple screen sizes (fenix 5/6/7, Venu, Edge devices)

## Project Statistics

- **Language:** Monkey C
- **Files:** 4 source files + 3 resource files
- **Lines of Code:** ~280 (excluding generated resources)
- **Supported Devices:** 150+
- **Minimum API Level:** 3.0.0

## Known Limitations

1. **Foreground Only** — The app closes when switched to another app (by design)
2. **Time Estimate Accuracy** — Charging rate varies; estimates assume constant rate
3. **Screen Timeout** — Some devices may dim/lock the screen during charging (device-dependent)
4. **Manual Reset Only** — No automatic reset; use menu button to start new measurements

## Future Enhancements

Potential improvements for future releases:
- Data logging to track charging history over time
- Customizable update intervals for slower charging devices
- Average charging rate across multiple sessions
- Battery health indicators
- Charging session history and statistics

## License

This project is provided as-is. Modify and distribute freely under the MIT License or your preferred open-source license.

## Author

Created as a practical utility for Garmin Connect IQ users who want to monitor their device's charging progress.

## Support

For issues, feature requests, or feedback:
1. Check the Garmin Connect IQ documentation
2. Review the source code comments for technical details
3. Test on the ConnectIQ Simulator with multiple device profiles
4. Submit issues through the appropriate channels

---

**Charging Screen** — Know your charging rate, estimate your wait time. ⚡
