#Requires AutoHotkey v2.0
#Include ../lol.ahk
plugins.Push(autoSkipPreEnd)

autoSkipPreEnd() {
    global gameflow
    static lastState := ""
    
    try {
        if (gameflow == "PreEndOfGame") {
            if (lastState != "PreEndOfGame") {
                lastState := "PreEndOfGame"
                LogToWeb("PreEndOfGame phase detected. Attempting to skip pre-end-of-game screen...", "info")
                res := APICall("POST", "/lol-pre-end-of-game/v1/skip-pre-end-of-game")
                if (IsObject(res) && res.Has("error")) {
                    LogToWeb("Failed to skip pre-end-of-game screen. Status: " res["status"], "error")
                } else {
                    LogToWeb("Successfully skipped pre-end-of-game screen.", "success")
                }
            }
        } else {
            lastState := gameflow
        }
    } catch Error as e {
        LogToWeb("Error skipping pre-end-of-game screen: " e.Message, "error")
    }
}
