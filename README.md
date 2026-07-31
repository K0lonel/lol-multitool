# League of Legends Multitool Dashboard

A companion dashboard for League of Legends built with AutoHotkey v2 and Microsoft WebView2. Interacts with the local League Client Update (LCU) API to automate queue acceptance, end-of-game reporting, and ARAM bench sniping.

---

## Features

### Dashboard UI
- Modern dark-themed dashboard built with HTML/CSS and Bootstrap 5.
- Collapsible cards that save layout preferences.
- Custom window title bar supporting dragging, minimizing, maximizing, and closing.
- Automatic preference saving to `config.json`.

### Client Monitoring
- Live LCU connection status tracking.
- Client gameflow phase and lobby statistics.
- One-click lobby dodge in Champion Select.
- Teammate summoner scraping with quick search links.
- Real-time event logging console.

### Match Automation
- **Auto-Accept**: Automatically accepts queue pops with a configurable delay (0–5s).
- **Bench Sniper**: Automatically picks target champions from the ARAM/Arena bench when available.
- **Role Presets & Favorites**: Filter targets by role or save custom favorites.
- **Visual Bench**: View bench state in real-time and swap champions manually.

### Post-Game Reporting
- **Automated Scanning**: Scans completed games in match history.
- **Targeted Reports**: Queues reports for lobby participants at game end.
- **Category Selection**: Customizable report reasons and comment templates.
- **Rate Limit Queue**: Sends reports sequentially to prevent client rate limits.
- **Safety Exclusions**: Automatically skips yourself and players on your friends list.

---

## Tech Stack

- **Core**: [AutoHotkey v2.0+](https://www.autohotkey.com/)
- **Frontend**: HTML5, CSS, Bootstrap 5
- **Rendering**: Microsoft WebView2 via [WebViewToo](https://github.com/The-CoDingman/WebViewToo)
- **API**: Local League Client Update (LCU) REST API (credentials fetched via WMI)

---

## Project Structure

```
league - WebView/
├── lol.ahk                  # Main AutoHotkey program controller & loop
├── config.json              # Persistent user preferences & automations
├── history.json             # Session history registry for reported games
├── plugins/                 # Modular automation tasks
│   ├── autoAccept.ahk       # Auto-accept ready check handler
│   ├── autoReport.ahk       # End-of-game auto-report processor & queue
│   └── champSelectHelper.ahk# Handles bench sniper, visual bench, and lobby scraping
└── lib/                     # AHK Helper Libraries
    ├── API.ahk              # Handles raw HTTP requests to the LCU port
    ├── Base64.ahk           # Base64 encoder helper for LCU authentication token
    ├── JSON.ahk             # AHK JSON parser and stringifier
    ├── LCU.ahk              # Uses WMI queries to fetch port and token from League client
    ├── globals.ahk          # Globals definitions
    ├── plugins.ahk          # Plugin registry/loader loader
    ├── utilities.ahk        # Utility functions (logging, list checks, time formatting)
    └── WebView2/            # WebView2 wrapper library (updated version)
        ├── WebViewToo.ahk   # High-level WebViewGui/WebViewCtrl classes
        ├── WebView2.ahk     # Core Edge WebView2 COM wrapper
        ├── Promise.ahk      # Promise helper class
        ├── ComVar.ahk       # Helper for COM variables
        ├── 32bit/           # 32-bit WebView2Loader binaries
        └── 64bit/           # 64-bit WebView2Loader binaries
└── Pages/                   # Web frontend pages mapped to ahk.localhost
    ├── index.html           # Main Dashboard HTML layout & controller
    ├── logo.svg             # Sidebar app logo
    └── Bootstrap/           # Custom Bootstrap styling, JS & fonts
```

---

## Configuration (`config.json`)

| Setting | Type | Description |
|---|---|---|
| `autoAccept` | boolean | Enables auto-accepting queue pops |
| `acceptDelay` | number | Delay in seconds before auto-accepting (0–5) |
| `autoReport` | boolean | Enables post-game auto-reporting |
| `reportCategories` | array | Selected report category strings |
| `reportComment` | string | Custom comment template for reports |
| `autoPickBenchEnabled` | boolean | Enables ARAM bench sniper |
| `autoPickBenchIds` | array | Champion IDs queued for bench sniper |
| `favoriteChampIds` | array | Favorite champion IDs |
| `foldSniper`, `foldAccept`, `foldReport` | boolean | Saved card collapse states |
| `windowWidth`, `windowHeight` | number | Saved window size |

---

## Hotkeys

Hotkeys are active when the application window is focused:

| Keybind | Action |
|---|---|
| `Ctrl + T` | Exit the application |
| `Ctrl + R` | Reload the application |

---

## Installation & Setup

### Prerequisites
- [AutoHotkey v2.0+](https://www.autohotkey.com/)
- Microsoft Edge WebView2 Runtime (included in Windows 10/11)

### Running
1. Launch the League of Legends Client and log in.
2. Run [`lol.ahk`](file:///D:/scripts/league%20-%20WebView/lol.ahk).

---

## Safeguards

- **Local Communication**: Communicates strictly over `127.0.0.1` with the local LCU API.
- **No Memory Modification**: Uses standard LCU REST endpoints instead of memory reading/writing.
- **Friend Protection**: Excludes your account and friends list from automated reports.
- **Manual Override**: Manually picking a champion pauses the bench sniper for that lobby.
