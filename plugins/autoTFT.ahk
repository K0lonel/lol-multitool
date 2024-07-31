#Requires AutoHotkey v2.0
#Include <../lib/utilities>
#Include <../lib/LCU>
#Include <../lib/API>
plugins.Push("autoTFT")

autoTFT(){
    static ff_Time := 600
    try {
        switch APICall("GET", "/lol-gameflow/v1/gameflow-phase") {
            case "ReadyCheck": APICall("POST", "/lol-matchmaking/v1/ready-check/accept")
            case "EndOfGame": APICall("POST", "/lol-lobby/v2/play-again")
            case "Lobby": APICall("POST", "/lol-lobby/v2/lobby/matchmaking/search")
            case "InProgress":
                time := floor(request("GET", LCU.Web_URL "/liveclientdata/gamestats")["gameTime"])
                MyWindow.ExecuteScript("document.querySelector('#tft_time').innerText = 'Game Time: " SecondsToTime(time) " / " SecondsToTime(ff_Time) "'")
                if(time > ff_Time) {
                    surrender()
                }
        }
    }
}

LeagueClick(x, y) {
    rx := (x / 1920) * A_ScreenWidth
    ry := (y / 1080) * A_ScreenHeight

    Click rx, ry, "3 Left Down"
    sleep 30
    Click rx, ry, "3 Left Up"
}

surrender() {
    WinActivate("ahk_exe League of Legends.exe")
    sleep(700)
    Send("{Esc}")
    sleep(500)
    LeagueClick(750, 840)
    sleep(500)
    LeagueClick(800, 480)
    Send("{Esc}")
    sleep(3000)
}