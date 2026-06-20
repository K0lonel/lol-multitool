#Requires AutoHotkey v2.0
#Include ../lol.ahk
plugins.Push(autoSkipPreEnd)

autoSkipPreEnd() {
    global config, gameflow, autoHonorCompleted
    static lastState := ""
    
    if (!config.Has("autoSkipPreEndEnabled") || !config["autoSkipPreEndEnabled"]) {
        lastState := ""
        return
    }
    
    ; If auto-honoring is enabled, do not skip pre-end-of-game until auto-honoring completes.
    if (config.Has("autoHonorerEnabled") && config["autoHonorerEnabled"] && IsSet(autoHonorCompleted) && !autoHonorCompleted) {
        return
    }
    
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
