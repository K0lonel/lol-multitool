#Requires AutoHotkey v2.0
#Include ../lol.ahk
plugins.Push(autoAccept)

autoAccept(){
    global config, gameflow
    if (!config.Has("autoAccept") || !config["autoAccept"])
        return

    static scheduledAccept := false
    try {
        if (gameflow == "ReadyCheck") {
            if (!scheduledAccept) {
                scheduledAccept := true
                delay := config.Has("acceptDelay") ? config["acceptDelay"] : 0
                LogToWeb("ReadyCheck detected. Auto-accept scheduled with a " delay "s delay.", "info")
                if (delay > 0) {
                    SetTimer(DoAcceptQueue, -delay * 1000)
                } else {
                    DoAcceptQueue()
                }
            }
        } else {
            scheduledAccept := false
        }
    }
}

DoAcceptQueue() {
    global gameflow
    if (gameflow == "ReadyCheck") {
        LogToWeb("Accepting matchmaking ready check...", "info")
        try {
            res := APICall("POST", "/lol-matchmaking/v1/ready-check/accept")
            if (IsObject(res) && res.Has("error")) {
                LogToWeb("Failed to accept ready check. Status: " res["status"], "error")
            } else {
                LogToWeb("Matchmaking ready check successfully accepted.", "success")
            }
        } catch Error as e {
            LogToWeb("Error accepting ready check: " e.Message, "error")
        }
    }
}