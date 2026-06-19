# 🎮 League of Legends Multitool Dashboard

An advanced, feature-rich companion dashboard for **League of Legends**, built using **AutoHotkey v2** and **WebView2** (Chromium). The tool features a premium, Hextech-inspired dark gold/blue UI that integrates directly with the local League Client Update (LCU) API to automate matchmaking acceptance, auto-report post-game lobbies, and snipe preferred champions from the ARAM bench.

---

## ✨ Features

### 1. Hextech Dashboard & User Experience
*   **Stunning Theme**: Dark mode layout featuring Outfit typography, smooth animations, gold-accented gradient cards, and pulsing glowing states.
*   **Responsive Collapsible Cards**: Custom panel folding (e.g., ARAM Bench Sniper, Auto-Accept, Auto-Report) that remembers your layout preferences (`foldSniper`, `foldAccept`, `foldReport`) and restores them on launch.
*   **Custom Web Title Bar**: Fully integrated borderless title bar supporting window drag (`ahk.DragWindow()`), minimizing, maximizing, and clean exiting.
*   **Persistent Preferences**: Automatically writes and maintains window geometry, toggle choices, auto-accept delay, and preset preferences to `config.json` on exit or reload.

### 2. Live Status Dashboard
*   **Connection Status**: Direct LCU connection tracking with color-coded status pills (CONNECTED, READYCHECK, DISCONNECTED).
*   **Game Stats Panel**: Live monitoring of client gameflow phase, cached matches, and players logged in the current session.
*   **Active Features Summary**: Quick badges showing the activation state of Auto-Accept, Auto-Report, and Bench Sniper.
*   **Champion Select & Dodge Helper**: When in Champion Select, a warning card displays letting you instantly dodge the lobby with a single click.
*   **Champion Draft Companion**: Automatically scrapes teammate summoner names in the lobby and displays them on the dashboard with a quick link to check them.
*   **Session Console Logs**: Real-time developer event logging direct from the AHK backend (informational, warning, success, and debug outputs).

### 3. Match Automation
*   **Auto-Accept**: Automatically accepts matchmaking queue checks with a humanizing delay slider (0 to 5 seconds) to avoid stream-snipers.
*   **ARAM Bench Sniper (Autopicker)**: Instantly claims preferred champions from the team bench (ARAM/Arena) the millisecond they are rerolled or discarded by teammates.
    *   **Role Presets**: Instantly filter and load targets using tags (Favorites, Mage, Marksman/ADC, Support, Tank, Fighter, Assassin).
    *   **Favorites List**: Customize a persistent list of favorites using an autocomplete champion search bar, and add/remove targets dynamically.
    *   **Interactive Visual Bench**: View current bench champions dynamically in a card. Click any champion to manually swap to them, which automatically pauses the auto-picker for that lobby.

### 4. Automated Post-Game Reporting
*   **Background Scanning**: Automatically scans match history for completed games (skipping custom, practice tool, and aborted games).
*   **Targeted Reporting**: Queues report payloads for all lobby participants at the end of every match.
*   **Exclusion Safeguards**: Automatically excludes yourself and any players on your League friends list from reports.
*   **Customization**: Select report categories (AFK, Assisting Enemy, Third-Party Tools, Rank Manipulation, Botting, Verbal Abuse, Inappropriate Name) and write your own comment template directly in the dashboard UI.
*   **Rate Limit Handling**: Reports are sent in the background spaced 1 second apart to prevent LCU rate limits, displaying an "Active Reporting Process" card showing progress.
*   **Report History Logs**: View a session log of reported matches. Includes a direct "Link" button to perform a u.gg multisearch on the reported lobby.

---

## 🛠️ Tech Stack & Architecture

*   **Core Logic**: [AutoHotkey v2.0+](https://www.autohotkey.com/) (main loop, hotkeys, LCU connectivity, JSON file serialization).
*   **Frontend UI**: Modern HTML5, Vanilla CSS, and **Bootstrap 5** styled with Hextech themes.
*   **Render Engine**: **Microsoft WebView2** wrapped via the newer [WebViewToo](https://github.com/The-CoDingman/WebViewToo) library integration to support Chromium rendering inside custom AHK GUIs.
*   **League Connection**: LCU API handler reading port/credentials dynamically from local processes (utilizes WMI querying for `LeagueClientUx.exe` command-line parameters).

---

## 📂 Project Structure

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

## ⚙️ Persistent Configuration (`config.json`)

The tool reads and updates `config.json` dynamically. It manages:
*   `autoAccept`: Toggles the auto-accept feature (`true`/`false`).
*   `acceptDelay`: Slider delay (in seconds, `0`-`5`) before clicking accept.
*   `autoReport`: Toggles post-game reporting (`true`/`false`).
*   `reportCategories`: Array of selected report categories (e.g., `["BOTTING", "VERBAL_ABUSE"]`).
*   `reportComment`: Custom comment string sent with reports (e.g., `"tried to lose"`).
*   `autoPickBenchEnabled`: Toggles ARAM Bench Sniper (`true`/`false`).
*   `autoPickBenchIds`: Array of champion IDs active in the bench sniper.
*   `favoriteChampIds`: Array of user-selected favorite champion IDs.
*   `foldSniper`, `foldAccept`, `foldReport`: Accordion folding state toggles (`true`/`false`).
*   `windowWidth`, `windowHeight`: Dimensions of the application window saved on exit.

---

## ⌨️ Focus-Locked Hotkeys

These system hotkeys capture keybinds **only** when the app window is actively focused, preventing interference with your game or other tasks:
*   `Ctrl + T`: Exit the application safely (runs standard `ExitSave` routine).
*   `Ctrl + R`: Reload the application workspace.

---

## 🚀 Setup & Installation

### Prerequisites
1. Ensure you have **AutoHotkey v2.0+** installed on your Windows machine.
2. Ensure Microsoft Edge WebView2 Runtime is installed (built into modern Windows 10/11).

### Running the App
1. Launch your **League of Legends Client** and log in.
2. Double-click [lol.ahk](file:///D:/scripts/league%20-%20WebView/lol.ahk) or run it from a shell.
3. The dashboard will automatically connect, read your LCU credentials via WMI, load your summoner stats, cache the champion list, and begin automation loops.

---

## 🔒 Safety & Safeguards
*   **Local Only**: All communications occur purely on `127.0.0.1` locally with your active game client. No credentials or account details are sent over the network.
*   **Anti-Cheat Compliance**: The app uses the client's internal LCU API rather than memory injection or pixel scanning, operating safely alongside Vanguard.
*   **Teammate/Friend Safeguards**: Hardcoded rules automatically exclude yourself and your friends list from being reported.
*   **User Manual Override**: If you manually swap to any champion from the visual bench, the Bench Sniper immediately pauses for that champion select lobby to prevent fighting you for selections.
