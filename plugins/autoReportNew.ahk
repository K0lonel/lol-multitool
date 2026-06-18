#Requires AutoHotkey v2.0
#Include ../lib/utilities.ahk
#Include ../lib/LCU.ahk
#Include ../lib/API.ahk
; #Include ../lib/globals.ahk
plugins.Push(autoReport)



autoReport(){
    try {
        report()
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
    global reportList

    for i, game in match_history["games"]["games"] {
        if(match_history_dic.Has(String(game["gameId"])) || (game["gameType"] == "CUSTOM_GAME"))
            continue

        detailed_history := APICall("GET", "/lol-match-history/v1/games/" game["gameId"])
        
        reportedPlayers := Array()
        for ii, participant in detailed_history["participantIdentities"] {
            if(participant["player"]["puuid"] != me["lol"]["puuid"]) {
                if(!HasVal(friend_puuid, participant["player"]["puuid"])) {
                    obj := {categories: categories, gameId: game["gameId"], offenderPuuid: participant["player"]["puuid"], offenderSummonerId: participant["player"]["summonerId"]}
                    try APICall("POST", "/lol-player-report-sender/v1/match-history-reports", JSON.Dump(obj))
                    catch Error as e
                        MsgBox(e.Message)
                    reportedPlayers.Push(participant["player"]["gameName"] "#" participant["player"]["tagLine"])
                }
            }
        }

        reportList := JSON.Dump(Map("Players", reportedPlayers, "Game", i "/" match_history["games"]["games"].Length),1)
        OutputDebug(reportList)
        MyWindow.ExecuteScript("document.querySelector('#jsonBox').textContent = JSON.stringify(" reportList ", null, 2)")
        match_history_dic[String(game["gameId"])] := Map("HistoryLink", "https://www.leagueofgraphs.com/match/eune/" game["gameId"]
                                                ,"ReportedPlayers", reportedPlayers)
    }
}