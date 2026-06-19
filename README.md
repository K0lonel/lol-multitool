# 🎮 League of Legends Multitool Dashboard

An advanced, feature-rich companion dashboard for **League of Legends**, built using **AutoHotkey v2** and **WebView2** (Chromium). The tool features a premium, Hextech-inspired dark gold/blue UI that integrates directly with the local League Client Update (LCU) API to automate lobby tasks, dodge-penalize trolls, and query player stats internally.

---

## ✨ Features

### 1. Hextech Dashboard & User Experience
*   **Stunning Theme**: Dark mode layout featuring Outfit typography, smooth animations, gold-accented gradient cards, and pulsing glowing states.
*   **Responsive Collapsible Cards**: Custom panel folding (e.g., Automation folders) that remembers your layout preferences (`foldSniper`, `foldAccept`, `foldReport`) and restores them on launch.
*   **Custom Web Title Bar**: Fully integrated borderless title bar supporting window drag (`ahk.DragWindow()`), minimizing, maximizing, and clean exiting.
*   **Persistent Preferences**: Automatically writes and maintains window sizes, toggle choices, auto-accept delay, and preset preferences to `config.json` on exit or reload.

### 2. Match Automation
*   **Auto-Accept**: Automatically clicks "Accept" on match found cues with support for custom delays (adjustable via a smooth slider) to avoid stream-snipers.
*   **Bench Champion Sniper (Autopicker)**: Instantly swaps and claims preferred champions from the team bench (ARAM/Arena) the millisecond they are rerolled or discarded.
    *   **Presets Filter**: Filter and load targets dynamically using tags (Mage, Marksman/ADC, Support, Tank, Fighter, Assassin).
    *   **Favorites List**: Customize a persistent list of favorites using an autocomplete champion search bar, and add/remove targets with a click.
    *   **Circular Crop Icons**: High-resolution, zoom-cropped circular champion face icons across all badges and benches.

### 3. Smart Auto-Reporting
*   **Troll Mitigation**: Automatically queues reports for lobby-dodgers or lobby-trolls in the background.
*   **Custom Categories**: Select custom report triggers (e.g., Botting, Feeding, Verbal Abuse, AFK) and write your own custom comment templates directly in the settings.

### 4. Built-in Web Scout
*   **Internal Profiling Tab**: A dedicated browser iframe directly inside the UI.
*   **Bypassed Blockers**: Initializes WebView2 with `--disable-web-security` flags. This enables loading external summoner analytics (`xdx.gg`) and multi-searches (`u.gg`) internally without getting blocked by frame security headers (`X-Frame-Options` / CSP).
*   **Browser Navigation**: Back/Reload navigation controls for streamlined tracking.

---

## 🛠️ Tech Stack & Architecture

*   **Core Logic**: [AutoHotkey v2.0+](https://www.autohotkey.com/) (main loop, hotkeys, LCU connectivity, JSON file serialization).
*   **Frontend UI**: Modern HTML5, Vanilla CSS, and **Bootstrap 5** styled with Hextech themes.
*   **Render Engine**: **Microsoft WebView2** wrapped via the [WebViewToo](https://github.com/The-Codingman/WebViewToo) library to support Chromium rendering inside AHK GUIs.
*   **League Connection**: LCU API handler reading port/credentials dynamically from the local client's `.lockfile`.

---

## ⌨️ Focus-Locked Hotkeys

These system hotkeys capture keybinds **only** when the app window is actively focused, preventing interference with other games or tasks:
*   `Ctrl + T`: Exit the application safely (runs standard `ExitSave`).
*   `Ctrl + R`: Reload the application workspace.

---

## 📂 Project Structure

```
league - WebView/
├── lol.ahk                  # Main AutoHotkey program controller & loop
├── config.json              # Persistent user preferences & automations
├── historyView.json         # Session history data
└── lib/                     # AHK Libraries and UI assets
    ├── API.ahk              # Handles raw HTTP calls to local League LCU port
    ├── JSON.ahk             # AHK JSON parser and stringifier
    ├── LCU.ahk              # Finds LCU client port & remoting auth token
    ├── utilities.ahk        # Utility functions (logging, helpers)
    └── WebViewToo/          # WebView2 wrapper library
        ├── AHK Resources/   # Core binaries & WebView2Loader dlls
        └── Pages/           # Web frontend pages
            ├── index.html   # Main Dashboard HTML layout & controller
            └── Bootstrap/   # Custom local Bootstrap styling, JS & fonts
```

---

## 🚀 Setup & Installation

### Prerequisites
1. Ensure you have **AutoHotkey v2.0+** installed on your Windows machine.
2. Ensure Microsoft Edge WebView2 Runtime is installed (built into modern Windows 10/11).

### Running the App
1. Launch your **League of Legends Client** and log in.
2. Double-click [lol.ahk](file:///D:/scripts/league%20-%20WebView/lol.ahk) or run it from a shell.
3. The dashboard will automatically connect, read your LCU credentials, load your summoner stats, and begin automation loops.

---

## 🔒 Safety & Safeguards
*   **Local Only**: All communications occur purely on `127.0.0.1` locally with your active game client. No account details are sent over the network.
*   **Safeguards**: Built-in options like *Exclude Friends List* protect your preset lobbies and teammates from accidental reports or automated snipes.
