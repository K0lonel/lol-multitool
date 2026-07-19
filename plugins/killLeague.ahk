#Requires AutoHotkey v2.0
#Include ../lol.ahk
global killLeagueEnabled := False
global reconnectTimeRemaining := 0
plugins.Push(killLeague)

killLeague() {
    global MyWindow, killLeagueEnabled, reconnectTimeRemaining
    static isWaiting := false
    static waitStartTime := 0
    static reconnectDelay := Integer(3.75 * 60 * 1000) ; 3.75 mins * 60 seconds * 1000 ms

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
                formattedTime := (reconnectDelay // 60000) . ":" . Format("{:02d}", Mod(reconnectDelay // 1000, 60))
                LogToWeb("League of Legends task ended successfully. Reconnecting in " . formattedTime . " minutes...", "success")
                
                reconnectTimeRemaining := reconnectDelay // 1000
                try MyWindow.ExecuteScriptAsync("document.getElementById('game-stats-reconnect-time').innerText = '" . formattedTime . "';")
                SetTimer(ReconnectCountdown, 1000)
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

ReconnectCountdown() {
    global reconnectTimeRemaining, MyWindow
    if (reconnectTimeRemaining > 0) {
        reconnectTimeRemaining--
        mins := reconnectTimeRemaining // 60
        secs := Mod(reconnectTimeRemaining, 60)
        timeStr := mins ":" Format("{:02d}", secs)
        
        try MyWindow.ExecuteScriptAsync("document.getElementById('game-stats-reconnect-time').innerText = '" timeStr "';")
        
        if (reconnectTimeRemaining <= 0) {
            SetTimer(ReconnectCountdown, 0)
            try MyWindow.ExecuteScriptAsync("document.getElementById('game-stats-reconnect-time').innerText = '--';")
            ReconnectLeague()
        }
    } else {
        SetTimer(ReconnectCountdown, 0)
        try MyWindow.ExecuteScriptAsync("document.getElementById('game-stats-reconnect-time').innerText = '--';")
    }
}

ReconnectLeague() {
    LogToWeb("Initiating scheduled reconnect to League of Legends game...", "info")
    try {
        res := LeagueAPI.ReconnectGameflow()
        if (IsObject(res) && res.Has("error")) {
            LogToWeb("Scheduled reconnect failed. Status: " (res.Has("status") ? res["status"] : "unknown") ", Error: " (res.Has("error") ? res["error"] : "unknown"), "error")
        } else {
            LogToWeb("Scheduled reconnect request sent successfully.", "success")
        }
    } catch Error as e {
        LogToWeb("Error during scheduled reconnect: " e.Message, "error")
    }
}
