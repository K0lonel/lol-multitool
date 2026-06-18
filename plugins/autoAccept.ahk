#Requires AutoHotkey v2.0
#Include ../lib/utilities.ahk
#Include ../lib/LCU.ahk
#Include ../lib/API.ahk
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
        try APICall("POST", "/lol-matchmaking/v1/ready-check/accept")
    }
}