#Requires AutoHotkey v2.0
#Include ../lib/utilities.ahk
#Include ../lib/LCU.ahk
#Include ../lib/API.ahk
; #Include ../lib/globals.ahk
plugins.Push(autoReport)

autoReport(){
    try {
        switch gameflow {
            case "EndOfGame": report()
        }
    }
}

report() {
    ; "NEGATIVE_ATTITUDE"
    ; "VERBAL_ABUSE"
    ; "LEAVING_AFK"
    ; "ASSISTING_ENEMY_TEAM"
    ; "HATE_SPEECH"
    ; "THIRD_PARTY_TOOLS"
    ; "INAPPROPRIATE_NAME"
    static categories := ["NEGATIVE_ATTITUDE", "VERBAL_ABUSE", "HATE_SPEECH", "THIRD_PARTY_TOOLS"]
    static s_gameId := -100
    eogStats := APICall("GET", "/lol-end-of-game/v1/eog-stats-block")
    
    if(eogStats["gameId"] == s_gameId)
        return

    friend_puuid := Array(), reportedPlayers := Array()
    for index, friend in friends
        friend_puuid.Push(friend["puuid"])

    for i, team in eogStats["teams"] {
        for ii, player in team["players"] {
            if(player["puuid"] != me["lol"]["puuid"]) {
                if(!HasVal(friend_puuid, player["puuid"])) {
                    obj := {categories: categories, gameId: eogStats["gameId"], offenderPuuid: player["puuid"], offenderSummonerId: player["summonerId"]}
                    APICall("POST", "/lol-player-report-sender/v1/end-of-game-reports", JSON.Dump(obj))
                    reportedPlayers.Push(player["championName"])
                }
            }
        }
    }
    s_gameId := eogStats["gameId"]
    ; MsgBox(objView(reportedPlayers))
    OutputDebug(objView(reportedPlayers))
    return
}