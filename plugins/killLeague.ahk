#Requires AutoHotkey v2.0
#Include ../lol.ahk
global killLeagueEnabled := False
plugins.Push(killLeague)

killLeague() {
    global MyWindow, killLeagueEnabled
    static isWaiting := false
    static waitStartTime := 0

    if (!killLeagueEnabled) {
        isWaiting := false
        return
    }

    if (!isWaiting) {
        if (WinExist("ahk_exe League of Legends.exe")) {
            isWaiting := true
            waitStartTime := A_TickCount
            LogToWeb("League of Legends client detected. Terminating task in 2 seconds...", "warning")
        }
    } else {
        ; Check if the window was closed/disappeared in the meantime
        if (!WinExist("ahk_exe League of Legends.exe")) {
            isWaiting := false
            LogToWeb("League of Legends client closed before termination.", "info")
            return
        }

        elapsed := A_TickCount - waitStartTime
        if (elapsed >= 2000) {
            try {
                ProcessClose("League of Legends.exe")
                LogToWeb("League of Legends task ended successfully.", "success")
            } catch Error as e {
                LogToWeb("Failed to end League of Legends task: " . e.Message, "error")
            }

            isWaiting := false

            ; Untoggle the variable (no SaveConfig since it's in-memory only)
            killLeagueEnabled := False

            ; Update WebView state
            try MyWindow.ExecuteScriptAsync("updateConfig('killLeagueEnabled', false)")
        }
    }
}
