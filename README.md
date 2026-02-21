# Flight Segment Picker

A desktop application for comparing and selecting multi-leg flight itineraries. Built with Qt/QML.

![Light mode](docs/screenshot-light.png)

## Overview

Flight Segment Picker lets you enter flight options for each leg of a multi-segment trip, then scroll through and compare combinations. It's designed for manually researching flights across airline websites and collecting them in one place to find the best itinerary.

The app is structured around 4 columns representing a round-trip with a stopover:

| Column | Route | Description |
|--------|-------|-------------|
| 1 | TLV → UAE | Outbound Leg 1 |
| 2 | UAE → Japan | Outbound Leg 2 |
| 3 | Japan → UAE | Return Leg 1 |
| 4 | UAE → TLV | Return Leg 2 |

Each column holds multiple flight cards. A highlight row spans all columns — the card at the highlight row in each column is the "selected" flight for that leg. Scroll each column independently to compare different combinations. The total price and layover durations update in real time.

## Features

- **4-column scrollable flight picker** with snap-to-cell selection
- **Calendar date picker** popup (opens upward, never clipped)
- **Editable combo boxes** for airlines and aircraft — new entries added dynamically
- **DST-aware flight duration** calculation (Israel summer/winter time)
- **Layover duration** display between adjacent segments
- **Card management** — add, edit (double-click), delete (X button)
- **Project files** (`.flp`) — save/load flight data separately from UI settings
- **Theme toggle** — dark mode (navy/gold) and light mode (Windows 10 style)
- **Persistent settings** — window geometry, theme, card height, last project
- **Command-line support** — `--project path/to/file.flp`
- **Native file dialogs** for Open/Save/Save As

## Building

### Requirements

- Qt 6.2+ (or Qt 5.15) with Quick, QuickControls2, and Widgets modules
- C++17 compiler (MSVC 2019+, GCC 9+, Clang 10+)

### With Qt Creator

1. Open `src/FlightPicker.pro` (qmake) or `src/CMakeLists.txt` (CMake)
2. Configure the project for your Qt kit
3. Build and run

### With CMake (command line)

```bash
cd src
mkdir build && cd build
cmake .. -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x.x/gcc_64
cmake --build .
./FlightPicker
```

### Debug mode

In Debug builds, QML files are loaded directly from the source directory — edit any `.qml` file and just restart the app, no rebuild needed. The console will print:

```
Loading QML from source: file:///path/to/src/main.qml
```

## Usage

### Adding flights

Use the input forms at the bottom of each column. Select departure/arrival airports, pick dates from the calendar, set times, and click **Add**.

### Selecting flights

Scroll each column to position your preferred flight at the highlight row. The **SELECTED** bar at the bottom shows the current combination with layover durations between segments.

### Editing and deleting

- **Double-click** a card to open the edit dialog
- **Hover** over a card to reveal the **✕** delete button

### Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+N | New project |
| Ctrl+O | Open project |
| Ctrl+S | Save project |
| Ctrl+Shift+S | Save As |

### Project files

Flight data is stored in `.flp` files (JSON format) which can be shared, emailed, or version-controlled. UI settings (window position, theme, card height) are stored separately in your system's app data directory.

### Tuning card height

Edit `flightpicker_settings.json` in your app data directory:

```json
{
    "cellHeight": 110
}
```

Values between 90 (compact) and 150 (spacious) work well. Restart the app to apply.

## File structure

```
src/
├── main.cpp              # App entry, CLI parsing, QML engine setup
├── appsettings.h         # UI settings persistence (AppData)
├── projectdata.h         # Flight data persistence (.flp files)
├── appstate.h            # Legacy (unused, kept for reference)
├── main.qml              # Root window, theme, layout, persistence logic
├── FlightColumn.qml      # Scrollable column (Flickable + Repeater)
├── FlightInputForm.qml   # Add-flight form with all input controls
├── DatePickerField.qml   # Calendar popup date picker
├── EditableCombo.qml     # Editable combo box with filtered dropdown
├── StyledCombo.qml       # Non-editable styled combo (airports)
├── FormField.qml         # Styled text input field
├── TimeTumbler.qml       # Hour/minute spinner
├── CMakeLists.txt        # CMake build config
├── FlightPicker.pro      # qmake build config
└── qml.qrc               # Qt resource file
```

## Airport data

Preconfigured airports with UTC offsets (DST-aware for Israel):

- **Israel:** TLV (UTC+2 winter / UTC+3 summer)
- **UAE:** AUH, DXB, DWC, SHJ (UTC+4)
- **Japan:** NRT, HND, KIX, NGO, CTS, FUK, ITM (UTC+9)

## License

MIT License — see [LICENSE](LICENSE).
