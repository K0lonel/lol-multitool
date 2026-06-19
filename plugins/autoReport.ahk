#Requires AutoHotkey v2.0

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
    if (processTimer >= 1) {
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
    
    categories := config["reportCategories"]
    
    if (!IsSet(match_history) || !match_history.Has("games") || !match_history["games"].Has("games"))
        return

    newMatchesFound := false
    for index, game in match_history["games"]["games"] {
        gameId := String(game["gameId"])
        
        ; If already processed, skip
        if (checkedGames.Has(gameId) || HasHistoryGame(gameId))
            continue
            
        ; Skip aborted, practice tool, or custom games
        if (game.Has("endOfGameResult") && game["endOfGameResult"] != "GameComplete")
            continue
        if (game.Has("gameMode") && game["gameMode"] == "PRACTICETOOL")
            continue
        if (game.Has("gameType") && game["gameType"] == "CUSTOM_GAME")
            continue
            
        reportStatus := "Scanning Match #" gameId "..."
        LogToWeb("Auto-Report: New match #" gameId " found. Scanning lobby participants...", "info")
            
        identities := ""
        if (game.Has("participantIdentities") && IsObject(game["participantIdentities"]) && game["participantIdentities"].Length > 1) {
            identities := game["participantIdentities"]
        } else {
            detailed_history := APICall("GET", "/lol-match-history/v1/games/" gameId)
            if (IsObject(detailed_history) && detailed_history.Has("participantIdentities")) {
                identities := detailed_history["participantIdentities"]
            }
        }
        
        if (identities == "" || !IsObject(identities) || identities.Length == 0) {
            LogToWeb("Auto-Report: Failed to fetch participant identities for match #" gameId ". Will retry later.", "warning")
            continue
        }
            
        ; Mark as checked only after successful retrieval
        checkedGames[gameId] := true
            
        ; Initialize history map entry with Timestamp
        gameCreation := game.Has("gameCreation") ? game["gameCreation"] : 0
        
        SetHistoryGame(gameId, Map(
            "ReportedPlayers", Array(),
            "Timestamp", gameCreation
        ))
        newMatchesFound := true

        identitiesCount := IsObject(identities) ? identities.Length : 0
        LogToWeb("Auto-Report: Match #" gameId " retrieved " identitiesCount " participant identities.", "debug")

        queuedForMatch := 0
        for pIndex, participant in identities {
            if (!IsObject(participant) || !participant.Has("player")) {
                LogToWeb("Auto-Report: Skip index " pIndex " - invalid participant or player key missing", "debug")
                continue
            }
            player := participant["player"]
            if (!IsObject(player)) {
                LogToWeb("Auto-Report: Skip index " pIndex " - player key is not object", "debug")
                continue
            }
            puuid := player.Has("puuid") ? player["puuid"] : ""
            if (puuid == "") {
                LogToWeb("Auto-Report: Skip index " pIndex " - player puuid is empty", "debug")
                continue
            }
            
            myPuuid := (IsObject(me) && me.Has("lol") && me["lol"].Has("puuid")) ? me["lol"]["puuid"] : ""
            
            ; Check if self or friend
            isSelf := (puuid == myPuuid)
            isFriend := friend_puuid.Has(puuid)
            playerName := (player.Has("gameName") && player.Has("tagLine")) ? (player["gameName"] "#" player["tagLine"]) : "Unknown Player"
            
            if (isSelf || isFriend) {
                LogToWeb("Auto-Report: Skip player " playerName " - self=" isSelf " friend=" isFriend, "debug")
                continue
            }
            
            ; Check if already in reportQueue to avoid duplicates
            alreadyQueued := false
            for queuedReport in reportQueue {
                if (queuedReport["gameId"] == gameId && queuedReport["offenderPuuid"] == puuid) {
                    alreadyQueued := true
                    break
                }
            }
            if (alreadyQueued) {
                LogToWeb("Auto-Report: Skip player " playerName " - already in queue", "debug")
                continue
            }
            
            ; Queue report payload
            reportQueue.Push(Map(
                "gameId", gameId,
                "offenderPuuid", puuid,
                "offenderSummonerId", player["summonerId"],
                "playerName", playerName,
                "categories", categories,
                "retries", 0
            ))
            queuedForMatch++
            LogToWeb("Auto-Report: Queued player " playerName " (puuid: " puuid ") for Match #" gameId, "debug")
        }
        LogToWeb("Auto-Report: Finished scan for Match #" gameId ". Queued " queuedForMatch " players.", "info")
    }
    
    if (newMatchesFound && reportQueue.Length > 0) {
        reportStatus := "Queued " reportQueue.Length " player reports."
        LogToWeb("Auto-Report: Queued " reportQueue.Length " player reports to pending queue.", "info")
    }
}

ProcessReportQueue() {
    global reportQueue, reportStatus, match_history_dic, config
    
    if (reportQueue.Length == 0) {
        if (reportStatus != "Idle" && !InStr(reportStatus, "Queued")) {
            reportStatus := "Idle"
        }
        return
    }
    
    payload := reportQueue[1]
    playerName := payload["playerName"]
    gameId := payload["gameId"]
    
    reportStatus := "Reporting " playerName " (Match #" gameId ")..."
    
    commentStr := config.Has("reportComment") ? config["reportComment"] : "tried to lose"
    
    obj := {
        categories: payload["categories"],
        comment: commentStr,
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
        if (!HasHistoryGame(gameId)) {
            SetHistoryGame(gameId, Map(
                "ReportedPlayers", Array(),
                "Timestamp", GetEpochMS()
            ))
        }
        gameItem := GetHistoryGame(gameId)
        reportedList := gameItem["ReportedPlayers"]
        reportedList.Push(playerName " (Skipped)")
        gameItem["ReportedPlayers"] := reportedList
        SetHistoryGame(gameId, gameItem)
        return
    }
    
    ; Success -> Append player name to reported list in history
    if (!HasHistoryGame(gameId)) {
        SetHistoryGame(gameId, Map(
            "ReportedPlayers", Array(),
            "Timestamp", GetEpochMS()
        ))
    }
    gameItem := GetHistoryGame(gameId)
    reportedList := gameItem["ReportedPlayers"]
    reportedList.Push(playerName)
    gameItem["ReportedPlayers"] := reportedList
    SetHistoryGame(gameId, gameItem)
    
    reportQueue.RemoveAt(1)
    
    if (reportQueue.Length > 0) {
        reportStatus := "Reported " playerName ". " reportQueue.Length " remaining."
        LogToWeb("Auto-Report: Reported player " playerName ". " reportQueue.Length " remaining in queue.", "success")
    } else {
        reportStatus := "All reports sent successfully!"
        LogToWeb("Auto-Report: Successfully finished reporting all players for Match #" gameId "!", "success")
    }
}

GetEpochMS() {
    return DateDiff(A_NowUTC, "19700101000000", "Seconds") * 1000
}