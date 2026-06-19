#Requires AutoHotkey v2.0
#Include ../lib/utilities.ahk
#Include ../lib/LCU.ahk
#Include ../lib/API.ahk

plugins.Push(autoReport)

autoReport(){
    global config
    if (!config.Has("autoReport") || !config["autoReport"])
        return
        
    static scanTimer := 0
    static processTimer := 0
    
    ; Scan for new matches in match history every 10 seconds
    scanTimer++
    if (scanTimer >= 10) {
        scanTimer := 0
        try {
            ScanNewMatches()
        } catch Error as e {
            LogToWeb("Auto-Report Error (Scan): " e.Message " at line " e.Line " in " e.File, "error")
        }
    }
    
    ; Process one enqueued player report every 2 seconds to avoid rate limiting
    processTimer++
    if (processTimer >= 2) {
        processTimer := 0
        try {
            ProcessReportQueue()
        } catch Error as e {
            LogToWeb("Auto-Report Error (Process): " e.Message " at line " e.Line " in " e.File, "error")
        }
    }
}

ScanNewMatches() {
    global match_history, match_history_dic, friend_puuid, me, config, reportQueue, reportStatus, checkedGames
    
    categories := (config.Has("reportCategories") && config["reportCategories"].Length > 0) ? config["reportCategories"] : ["LEAVING_AFK", "ASSISTING_ENEMY_TEAM", "THIRD_PARTY_TOOLS", "RANK_MANIPULATION", "BOTTING", "VERBAL_ABUSE", "INAPPROPRIATE_NAME"]
    
    if (!IsSet(match_history) || !match_history.Has("games") || !match_history["games"].Has("games"))
        return

    newMatchesFound := false
    for index, game in match_history["games"]["games"] {
        gameId := game["gameId"]
        gameIdStr := String(gameId)
        
        ; If already processed, skip
        if (HasVal(checkedGames, gameId) || HasVal(checkedGames, gameIdStr) || HasHistoryGame(gameId))
            continue
            
        ; Skip aborted, practice tool, or custom games
        if (game.Has("endOfGameResult") && game["endOfGameResult"] != "GameComplete")
            continue
        if (game.Has("gameMode") && game["gameMode"] == "PRACTICETOOL")
            continue
        if (game.Has("gameType") && game["gameType"] == "CUSTOM_GAME")
            continue
            
        reportStatus := "Scanning Match #" gameIdStr "..."
        LogToWeb("Auto-Report: New match #" gameIdStr " found. Scanning lobby participants...", "info")
            
        identities := ""
        if (game.Has("participantIdentities") && IsObject(game["participantIdentities"]) && game["participantIdentities"].Length > 0) {
            identities := game["participantIdentities"]
        } else {
            detailed_history := APICall("GET", "/lol-match-history/v1/games/" gameId)
            if (IsObject(detailed_history) && detailed_history.Has("participantIdentities")) {
                identities := detailed_history["participantIdentities"]
            }
        }
        
        if (identities == "" || !IsObject(identities) || identities.Length == 0) {
            LogToWeb("Auto-Report: Failed to fetch participant identities for match #" gameIdStr ". Will retry later.", "warning")
            continue
        }
            
        ; Mark as checked only after successful retrieval
        checkedGames.Push(gameId)
        checkedGames.Push(gameIdStr)
            
        ; Initialize history map entry with Timestamp linking to LoLalytics
        gameCreation := game.Has("gameCreation") ? game["gameCreation"] : 0
        
        SetHistoryGame(gameId, Map(
            "HistoryLink", GetLolalyticsLink(),
            "ReportedPlayers", Array(),
            "Timestamp", gameCreation
        ))
        newMatchesFound := true

        for pIndex, participant in identities {
            if (!IsObject(participant) || !participant.Has("player"))
                continue
            player := participant["player"]
            if (!IsObject(player))
                continue
            puuid := player.Has("puuid") ? player["puuid"] : ""
            if (puuid == "")
                continue
            
            myPuuid := (IsObject(me) && me.Has("lol") && me["lol"].Has("puuid")) ? me["lol"]["puuid"] : ""
            ; Skip self and friends
            if (puuid == myPuuid || HasVal(friend_puuid, puuid))
                continue
                
            playerName := (player.Has("gameName") && player.Has("tagLine")) ? (player["gameName"] "#" player["tagLine"]) : "Unknown Player"
            
            ; Check if already in reportQueue to avoid duplicates
            alreadyQueued := false
            for queuedReport in reportQueue {
                if (queuedReport["gameId"] == gameId && queuedReport["offenderPuuid"] == puuid) {
                    alreadyQueued := true
                    break
                }
            }
            if (alreadyQueued)
                continue
                
            ; Queue report payload
            reportQueue.Push(Map(
                "gameId", gameId,
                "offenderPuuid", puuid,
                "offenderSummonerId", player["summonerId"],
                "playerName", playerName,
                "categories", categories,
                "retries", 0
            ))
        }
    }
    
    if (newMatchesFound && reportQueue.Length > 0) {
        reportStatus := "Queued " reportQueue.Length " player reports."
        LogToWeb("Auto-Report: Queued " reportQueue.Length " player reports to pending queue.", "info")
    }
}

ProcessReportQueue() {
    global reportQueue, reportStatus, match_history_dic
    
    if (reportQueue.Length == 0) {
        if (reportStatus != "Idle" && !InStr(reportStatus, "Queued")) {
            reportStatus := "Idle"
        }
        return
    }
    
    payload := reportQueue[1]
    playerName := payload["playerName"]
    gameIdStr := String(payload["gameId"])
    
    reportStatus := "Reporting " playerName " (Match #" gameIdStr ")..."
    LogToWeb("Auto-Report: Submitting report for " playerName " (Match #" gameIdStr ")...", "info")
    
    obj := {
        categories: payload["categories"],
        comment: "tried to lose",
        gameId: payload["gameId"],
        offenderPuuid: payload["offenderPuuid"],
        offenderSummonerId: payload["offenderSummonerId"]
    }
    
    response := APICall("POST", "/lol-player-report-sender/v1/match-history-reports", JSON.Dump(obj))
    
    if (IsObject(response) && response.Has("error") && response["error"] == "Offline") {
        reportStatus := "LCU disconnected. Report queue paused."
        return
    }
    
    ; Rate Limited -> Keep payload at top of queue, log, wait longer
    if (IsObject(response) && response.Has("error") && response["error"] == "RateLimit") {
        payload["retries"] := payload["retries"] + 1
        reportStatus := "Rate limited. Retrying " playerName " (Attempt " payload["retries"] ")..."
        LogToWeb("Auto-Report: API Rate Limit hit reporting " playerName ". Retrying (attempt " payload["retries"] ") in 3 seconds...", "warning")
        sleep 3000
        return
    }
    
    ; Other HTTP Error (e.g. 400 Bad Request if already reported or invalid player)
    if (IsObject(response) && response.Has("error") && response["error"] == "HTTPError") {
        reportQueue.RemoveAt(1)
        reportStatus := "Skipped " playerName " (HTTP Error " response["status"] ")"
        LogToWeb("Auto-Report: Skipped reporting " playerName " due to LCU error (HTTP " response["status"] ").", "error")
        
        ; Still append as skipped to history so it's recorded
        if (!HasHistoryGame(gameIdStr)) {
            SetHistoryGame(gameIdStr, Map(
                "HistoryLink", GetLolalyticsLink(),
                "ReportedPlayers", Array(),
                "Timestamp", A_NowUTC
            ))
        }
        gameItem := GetHistoryGame(gameIdStr)
        reportedList := gameItem["ReportedPlayers"]
        reportedList.Push(playerName " (Skipped)")
        gameItem["ReportedPlayers"] := reportedList
        SetHistoryGame(gameIdStr, gameItem)
        return
    }
    
    ; Success -> Append player name to reported list in history
    if (!HasHistoryGame(gameIdStr)) {
        SetHistoryGame(gameIdStr, Map(
            "HistoryLink", GetLolalyticsLink(),
            "ReportedPlayers", Array(),
            "Timestamp", A_NowUTC
        ))
    }
    gameItem := GetHistoryGame(gameIdStr)
    reportedList := gameItem["ReportedPlayers"]
    reportedList.Push(playerName)
    gameItem["ReportedPlayers"] := reportedList
    SetHistoryGame(gameIdStr, gameItem)
    
    reportQueue.RemoveAt(1)
    
    if (reportQueue.Length > 0) {
        reportStatus := "Reported " playerName ". " reportQueue.Length " remaining."
        LogToWeb("Auto-Report: Reported player " playerName ". " reportQueue.Length " remaining in queue.", "success")
    } else {
        reportStatus := "All reports sent successfully!"
        LogToWeb("Auto-Report: Successfully finished reporting all players for Match #" gameIdStr "!", "success")
    }
}

GetLolalyticsLink() {
    global me
    region := "eune"
    gameName := (IsObject(me) && me.Has("lol") && me["lol"].Has("gameName")) ? me["lol"]["gameName"] : ""
    tagLine := (IsObject(me) && me.Has("lol") && me["lol"].Has("tagLine")) ? me["lol"]["tagLine"] : ""
    
    if (gameName == "")
        return "https://lolalytics.com/lol/summoner/eune/"
    
    cleanName := StrReplace(gameName, " ", "")
    return "https://lolalytics.com/lol/summoner/" region "/" cleanName "-" tagLine
}