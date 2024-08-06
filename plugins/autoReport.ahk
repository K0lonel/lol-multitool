#Requires AutoHotkey v2.0
#Include <../lib/utilities>
#Include <../lib/LCU>
#Include <../lib/API>
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
    static s_gameId := 0
    eogStats := APICall("GET", "/lol-end-of-game/v1/eog-stats-block")
    if(eogStats["gameId"] == s_gameId)
        return

    friend_puuid := Array()
    for index, friend in APICall("GET", "/lol-chat/v1/friends")
        friend_puuid.Push(friend["puuid"])

    s_gameId := eogStats["gameId"]
    localPlayerPuuid := eogStats["localPlayer"]["puuid"]
    for i, team in eogStats["teams"] {
        for ii, player in team["players"] {
            if(player["puuid"] != localPlayerPuuid) {
                if(!HasVal(friend_puuid, player["puuid"])) {
                    obj := {categories: categories, gameId: eogStats["gameId"], offenderPuuid: player["puuid"], offenderSummonerId: player["summonerId"]}
                    APICall("POST", "/lol-player-report-sender/v1/in-game-reports", JSON.Dump(obj))
                }
                ; test friend report ignoring
            }
        }
    }

    return
}