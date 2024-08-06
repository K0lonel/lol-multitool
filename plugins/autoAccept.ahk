#Requires AutoHotkey v2.0
#Include <../lib/utilities>
#Include <../lib/LCU>
#Include <../lib/API>
plugins.Push(autoAccept)

autoAccept(){
    static ff_Time := 600
    try {
        switch gameflow {
            case "ReadyCheck": APICall("POST", "/lol-matchmaking/v1/ready-check/accept")
        }
    }
}