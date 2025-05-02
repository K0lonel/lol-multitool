#Requires AutoHotkey v2.0
#Include ../lib/utilities.ahk
#Include ../lib/LCU.ahk
#Include ../lib/API.ahk
; #Include ../lib/globals.ahk
plugins.Push(autoReport)

autoReport(){
    try {
        switch gameflow {
            ; case "EndOfGame": report()
            case "None": report()
            case "Lobby": report()
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


    for i, game in match_history["games"]["games"] {
        if(match_history_dic.Has(String(game["gameId"])) || (game["gameType"] == "CUSTOM_GAME"))
            continue

        friend_puuid := Array(), reportedPlayers := Array()
        for index, friend in friends
            friend_puuid.Push(friend["puuid"])

        detailed_history := APICall("GET", "/lol-match-history/v1/games/" game["gameId"])

        for ii, participant in detailed_history["participantIdentities"] {
            if(participant["player"]["puuid"] != me["lol"]["puuid"]) {
                if(!HasVal(friend_puuid, participant["player"]["puuid"])) {
                    obj := {categories: categories, gameId: game["gameId"], offenderPuuid: participant["player"]["puuid"], offenderSummonerId: participant["player"]["summonerId"]}
                    try APICall("POST", "/lol-player-report-sender/v1/match-history-reports", JSON.Dump(obj))
                    catch Error as e
                        msgbox(e.Message)
                    reportedPlayers.Push(participant["player"]["gameName"])
                }

            }
        }
        match_history_dic[game["gameId"]] := Map("HistoryLink", "https://www.leagueofgraphs.com/match/eune/" game["gameId"]
                                                ,"ReportedPlayers", reportedPlayers)
    }
}