#Requires AutoHotkey v2.0
#Include ../lol.ahk
plugins.Push(champSelectHelper)

global champLobbyNames := Array()
global lastSessionId := ""
global warnedNoIds := false
global warnedEmpty := false
global bypassAutoPick := false
global lastSentChampId := 0

champSelectHelper() {
    global config, gameflow
    static wasInChampSelect := false
    static sessionFailCount := 0
    
    if (gameflow == "ChampSelect") {
        if (!wasInChampSelect) {
            wasInChampSelect := true
            sessionFailCount := 0
            LogToWeb("Entered Champion Select lobby. Active Draft Companion initialized.", "info", "champSelectHelperSilent")
            ; Log sniper status on entry
            if (config.Has("autoPickBenchEnabled") && config["autoPickBenchEnabled"]) {
                targetNames := GetTargetChampNames()
                LogToWeb("Bench Sniper: ARMED on lobby entry. Targets: " targetNames, "success", "champSelectHelperSilent")
            } else {
                LogToWeb("Bench Sniper: DISABLED on lobby entry. Toggle the sniper ON to activate.", "warning", "champSelectHelperSilent")
            }
        }
        try {
            session := LeagueAPI.GetChampSelectSession()
            if (IsObject(session) && !session.Has("error")) {
                sessionFailCount := 0
                ScanChampSelectLobby(session)
                UpdateChampSelectFrontend(session)
                ProcessBenchSwaps(session)
                ProcessChampMessages(session)
            } else if (IsObject(session) && session.Has("error")) {
                sessionFailCount++
                errCode := session.Has("status") ? session["status"] : "?"
                errType := session.Has("error") ? session["error"] : "?"
                if (errType == "Offline") {
                    if (sessionFailCount == 1)
                        LogToWeb("Bench Sniper: LCU went offline during ChampSelect.", "error", "champSelectHelperSilent")
                } else if (errCode == 404) {
                    if (sessionFailCount <= 3)
                        LogToWeb("Bench Sniper: Session not ready yet (404). Waiting... (attempt " sessionFailCount ")", "debug", "champSelectHelperSilent")
                    else if (sessionFailCount == 10)
                        LogToWeb("Bench Sniper: Session still returning 404 after 10 attempts.", "warning", "champSelectHelperSilent")
                } else {
                    LogToWeb("Bench Sniper: Session query failed — HTTP " errCode " (" errType "). Attempt " sessionFailCount, "warning", "champSelectHelperSilent")
                }
            } else {
                sessionFailCount++
                LogToWeb("Bench Sniper: Session returned unexpected data type: " Type(session), "error", "champSelectHelperSilent")
            }
        } catch Error as e {
            LogToWeb("ChampSelect Error: " e.Message " at line " e.Line, "error", "champSelectHelperSilent")
        }
    } else {
        if (wasInChampSelect) {
            wasInChampSelect := false
            sessionFailCount := 0
            LogToWeb("Exited Champion Select lobby.", "info", "champSelectHelperSilent")
            ResetChampSelectHelper()
        }
    }
}

ScanChampSelectLobby(session) {
    global config, lastSessionId, champLobbyNames
    
    if (!session.Has("myTeam"))
        return
        
    sessionId := session.Has("chatDetails") ? session["chatDetails"]["multiUserChatId"] : ""
    if (sessionId == lastSessionId && lastSessionId != "")
        return
        
    lastSessionId := sessionId
    champLobbyNames := Array()
    
    LogToWeb("Draft Companion: Scraping team lobby participants...", "info", "champSelectHelperSilent")
    for player in session["myTeam"] {
        nameWithTag := ""
        if (player.Has("nameVisibilityType") && player["nameVisibilityType"] == "VISIBLE") {
            if (player.Has("gameName") && player.Has("tagLine")) {
                nameWithTag := player["gameName"] "#" player["tagLine"]
            }
        }
        
        if (nameWithTag == "") {
            puuid := player.Has("puuid") ? player["puuid"] : ""
            if (puuid != "") {
                nameWithTag := GetSummonerNameByPuuid(puuid)
            }
        }
        
        if (nameWithTag != "" && !InStr(nameWithTag, "Teammate")) {
            champLobbyNames.Push(nameWithTag)
            
            if (config.Has("blacklistEnabled") && config["blacklistEnabled"] && config.Has("blacklist")) {
                for entry in config["blacklist"] {
                    entryName := ""
                    entryNote := ""
                    if (IsObject(entry)) {
                        entryName := entry.Has("name") ? entry["name"] : ""
                        entryNote := entry.Has("note") ? entry["note"] : ""
                    } else {
                        entryName := entry
                    }
                    if (entryName != "" && StrCompare(nameWithTag, entryName, false) == 0) {
                        alertMsg := "WARNING: Blacklisted player " nameWithTag " detected in lobby!"
                        if (entryNote != "") {
                            alertMsg .= " Note: " entryNote
                        }
                        if (!config.Has("blacklistSilent") || !config["blacklistSilent"]) {
                            LogToWeb(alertMsg, "error")
                        }
                    }
                }
            }
        }
    }
    
    if (champLobbyNames.Length > 0) {
        LogToWeb("Draft Companion: Successfully scraped lobby players: " JSON.Dump(champLobbyNames), "success", "champSelectHelperSilent")
        MyWindow.ExecuteScriptAsync("onLobbyScraped(" JSON.Dump(champLobbyNames) ")")
    }
}

; Helper: get formatted target champion name list for logging
GetTargetChampNames() {
    global config
    if (!config.Has("autoPickBenchIds") || !IsObject(config["autoPickBenchIds"]) || config["autoPickBenchIds"].Length == 0)
        return "[none]"
    
    names := Array()
    for id in config["autoPickBenchIds"] {
        names.Push(GetChampionName(id) "(" Type(id) ":" id ")")
    }
    joined := ""
    for name in names {
        joined .= (joined == "" ? "" : ", ") name
    }
    return "[" joined "]"
}

; Helper: find the local player's cell and current champion from the session
GetMyChampInfo(session) {
    result := Map("cellId", -1, "championId", 0, "championName", "Unknown")
    
    if (!session.Has("localPlayerCellId"))
        return result
    
    myCellId := session["localPlayerCellId"]
    result["cellId"] := myCellId
    
    if (session.Has("myTeam")) {
        for player in session["myTeam"] {
            if (player.Has("cellId") && player["cellId"] == myCellId) {
                if (player.Has("championId")) {
                    result["championId"] := player["championId"]
                    result["championName"] := GetChampionName(player["championId"])
                }
                break
            }
        }
    }
    return result
}

; Helper: dump all top-level keys from a Map/Object for debugging
DumpSessionKeys(session) {
    keys := ""
    if (Type(session) == "Map") {
        for k, v in session {
            valPreview := IsObject(v) ? Type(v) : SubStr(String(v), 1, 30)
            keys .= (keys == "" ? "" : ", ") k "(" valPreview ")"
        }
    }
    return keys
}

; Helper: resolve the bench array from session
; Returns the bench array or an empty string with reason
GetBenchFromSession(session) {
    if (session.Has("benchChampions")) {
        val := session["benchChampions"]
        if (IsObject(val) && Type(val) == "Array") {
            if (val.Length > 0) {
                return Map("data", val, "key", "benchChampions", "error", "")
            } else {
                return Map("data", "", "key", "benchChampions", "error", "benchChampions is empty")
            }
        }
        return Map("data", "", "key", "benchChampions", "error", "benchChampions is not an Array")
    }
    return Map("data", "", "key", "", "error", "No benchChampions key found in session")
}

; Helper: normalize a bench entry to get the champion ID
; benchChampions entries are objects with championId, benchChampionIds entries are raw IDs
GetBenchChampId(entry) {
    if (IsObject(entry) && entry.Has("championId"))
        return entry["championId"]
    if (!IsObject(entry))
        return entry  ; raw ID (integer or string)
    return 0
}

; Helper: dump preferred IDs with their types for debugging
DumpPreferredRaw() {
    global config
    if (!config.Has("autoPickBenchIds"))
        return "NO_KEY"
    ids := config["autoPickBenchIds"]
    if (!IsObject(ids))
        return "NOT_OBJECT(" Type(ids) ")"
    if (ids.Length == 0)
        return "EMPTY"
    
    dump := ""
    for id in ids {
        dump .= (dump == "" ? "" : ", ") id "(" Type(id) ")"
    }
    return "[" dump "]"
}

ProcessBenchSwaps(session) {
    global config, warnedNoIds, warnedEmpty
    static lastBenchState := ""
    static lastBenchEmpty := false
    static tickCount := 0
    static sessionKeysDumped := false
    tickCount++
    
    ; --- Dump session keys once so we know what fields exist ---
    if (!sessionKeysDumped) {
        sessionKeysDumped := true
        LogToWeb("Bench Sniper: Session keys: " DumpSessionKeys(session), "debug", "champSelectHelperSilent")
    }
    
    ; --- Gate: Is the bench actually enabled in this queue session? ---
    benchEnabled := session.Has("benchEnabled") && (session["benchEnabled"] = true || session["benchEnabled"] = "true")
    if (!benchEnabled) {
        if (Mod(tickCount, 10) == 1) {
            LogToWeb("Bench Sniper: [SKIP] Bench is not enabled in this session.", "debug", "champSelectHelperSilent")
        }
        return
    }
    
    benchResult := GetBenchFromSession(session)
    myInfo := GetMyChampInfo(session)
    
    ; --- Gate 0: Has the user manually bypassed the auto-picker? ---
    global bypassAutoPick
    if (bypassAutoPick) {
        if (Mod(tickCount, 10) == 1) {
            LogToWeb("Bench Sniper: [SKIP] bypassAutoPick is True (manual override active).", "debug", "champSelectHelperSilent")
        }
        return
    }
    
    ; --- Gate 1: Is the sniper enabled? ---
    sniperHasKey := config.Has("autoPickBenchEnabled")
    sniperValue := sniperHasKey ? config["autoPickBenchEnabled"] : "N/A"
    
    if (!sniperHasKey || !config["autoPickBenchEnabled"]) {
        if (Mod(tickCount, 10) == 1) {
            LogToWeb("Bench Sniper: [SKIP] Sniper is OFF (autoPickBenchEnabled=" sniperValue "). Enable it to activate.", "debug", "champSelectHelperSilent")
        }
        return
    }
    
    ; --- Gate 2: Check if bench data was missing ---
    if (benchResult["data"] == "") {
        if (Mod(tickCount, 10) == 1) {
            LogToWeb("Bench Sniper: [SKIP] No bench champions found. Error: " benchResult["error"], "debug", "champSelectHelperSilent")
        }
        return
    }
    
    benchData := benchResult["data"]
    benchKeyName := benchResult["key"]
    
    ; Log target configuration info periodically
    if (Mod(tickCount, 10) == 1) {
        targetsList := config.Has("autoPickBenchIds") ? DumpPreferredRaw() : "N/A"
        ; LogToWeb("Bench Sniper Check: tickCount=" tickCount ", benchCount=" benchData.Length ", targets=" targetsList, "debug", "champSelectHelperSilent")
    }
    
    ; --- Gate 3: Do we have target champion IDs configured? ---
    if (!config.Has("autoPickBenchIds") || !IsObject(config["autoPickBenchIds"])) {
        if (!warnedNoIds) {
            LogToWeb("Bench Sniper: [SKIP] Target IDs config missing. Has key=" config.Has("autoPickBenchIds"), "warning", "champSelectHelperSilent")
            warnedNoIds := true
        }
        return
    }
        
    preferredIdsArray := config["autoPickBenchIds"]
    if (preferredIdsArray.Length == 0) {
        if (!warnedEmpty) {
            LogToWeb("Bench Sniper: [SKIP] Target list is empty. Add champions to snipe.", "warning", "champSelectHelperSilent")
            warnedEmpty := true
        }
        return
    }
    
    preferredIds := Map()
    for id in preferredIdsArray {
        preferredIds[id] := true
    }
    
    ; --- Gate 4: Don't swap if we already have a target champion ---
    myChampId := myInfo["championId"]
    alreadyHaveTarget := preferredIds.Has(myChampId)
    if (alreadyHaveTarget) {
        static lastOwnedLog := ""
        ownedKey := myChampId
        if (ownedKey != lastOwnedLog) {
            lastOwnedLog := ownedKey
            LogToWeb("Bench Sniper: Already holding target " myInfo["championName"] " (ID:" myChampId "). No swap needed.", "success", "champSelectHelperSilent")
        }
        return
    }
    
    ; --- All gates passed! ---
    ; Build bench state string for change detection
    benchStateStr := ""
    for entry in benchData {
        benchStateStr .= GetBenchChampId(entry) ","
    }
    
    ; Track bench change
    if (benchStateStr != lastBenchState) {
        lastBenchState := benchStateStr
    }
    
    ; --- Attempt swap for first match ---
    for entry in benchData {
        champId := GetBenchChampId(entry)
        champName := GetChampionName(champId)
        matched := preferredIds.Has(champId)
        
        if (Mod(tickCount, 5) == 1) {
            LogToWeb("Bench Sniper: Checking bench champ " champName " (ID:" champId ") against targets. Match result=" (matched ? "TRUE" : "FALSE"), "debug", "champSelectHelperSilent")
        }
        
        if (matched) {
            LogToWeb("Bench Sniper: Target MATCHED! Attempting swap for " champName " (ID:" champId ")...", "warning", "champSelectHelperSilent")
            res := LeagueAPI.SwapBenchChampion(champId)
            
            LogToWeb("Bench Sniper: Swap API response received. Type=" Type(res) " isObject=" IsObject(res), "debug", "champSelectHelperSilent")
            
            if (IsObject(res) && res.Has("error")) {
                errStatus := res.Has("status") ? res["status"] : "?"
                errMsg := res.Has("error") ? res["error"] : "Unknown"
                LogToWeb("Bench Sniper: SWAP FAILED — " champName " — HTTP " errStatus " (" errMsg ")", "error", "champSelectHelperSilent")
            } else {
                LogToWeb("Bench Sniper: SWAP SENT for " champName " successfully. Verifying...", "success", "champSelectHelperSilent")
                ; Confirm swap
                try {
                    Sleep(300)
                    confirmSession := LeagueAPI.GetChampSelectSession()
                    if (IsObject(confirmSession) && !confirmSession.Has("error")) {
                        newInfo := GetMyChampInfo(confirmSession)
                        if (newInfo["championId"] == champId) {
                            LogToWeb("Bench Sniper: CONFIRMED — you now have " newInfo["championName"], "success", "champSelectHelperSilent")
                        } else {
                            LogToWeb("Bench Sniper: NOT CONFIRMED — expected " champName " but have " newInfo["championName"] " (ID:" newInfo["championId"] "). Server may have rejected swap.", "warning", "champSelectHelperSilent")
                        }
                    } else {
                        LogToWeb("Bench Sniper: Could not confirm — session re-fetch failed.", "warning", "champSelectHelperSilent")
                    }
                } catch Error as e {
                    LogToWeb("Bench Sniper: Could not confirm — " e.Message, "warning", "champSelectHelperSilent")
                }
            }
            
            lastBenchState := ""
            return
        }
    }
}

UpdateChampSelectFrontend(session) {
    global config
    
    if (!session.Has("myTeam")) {
        return
    }
    
    myTeamId := 0
    ; Build team list
    teamArr := Array()
    for player in session["myTeam"] {
        puuid := player.Has("puuid") ? player["puuid"] : ""
        cellId := player.Has("cellId") ? player["cellId"] : -1
        isMe := (cellId == session["localPlayerCellId"])
        
        teamVal := player.Has("team") ? player["team"] : 0
        myTeamSize := session["myTeam"].Length
        
        ; Fallback team identification if "team" key is missing
        if (teamVal == 0) {
            if (cellId < myTeamSize) {
                teamVal := 1
            } else {
                teamVal := 2
            }
        }
        
        if (isMe) {
            myTeamId := teamVal
        }
        
        position := -1
        if (teamVal == 1) {
            ; Since cellId is 0-indexed (0 to 4), we add 1 to make position 1-indexed (between 1 and myTeamSize)
            position := cellId + 1
        } else if (teamVal == 2) {
            ; Performing cellId - myTeamSize to find current position, plus 1 to make it 1-indexed (between 1 and myTeamSize)
            position := cellId - myTeamSize + 1
        }
        
        nameWithTag := ""
        if (player.Has("nameVisibilityType") && player["nameVisibilityType"] == "VISIBLE") {
            if (player.Has("gameName") && player.Has("tagLine")) {
                nameWithTag := player["gameName"] "#" player["tagLine"]
            }
        }
        
        if (nameWithTag == "") {
            if (puuid != "") {
                nameWithTag := GetSummonerNameByPuuid(puuid)
            }
            if (nameWithTag == "") {
                nameWithTag := "Teammate " (position >= 1 ? position : "")
            }
        }
        
        ; Split name and tag
        gameName := ""
        tagLine := ""
        if (nameWithTag != "") {
            parts := StrSplit(nameWithTag, "#")
            if (parts.Length >= 1)
                gameName := parts[1]
            if (parts.Length >= 2)
                tagLine := parts[2]
        }
        
        champId := player.Has("championId") ? player["championId"] : 0
        champName := champId > 0 ? GetChampionName(champId) : ""
        
        spell1Id := player.Has("spell1Id") ? player["spell1Id"] : 0
        spell2Id := player.Has("spell2Id") ? player["spell2Id"] : 0
        
        ; Check if blacklisted
        isBlacklisted := false
        blacklistNote := ""
        if (config.Has("blacklistEnabled") && config["blacklistEnabled"] && config.Has("blacklist") && nameWithTag != "" && !InStr(nameWithTag, "Teammate")) {
            for entry in config["blacklist"] {
                entryName := ""
                entryNote := ""
                if (IsObject(entry)) {
                    entryName := entry.Has("name") ? entry["name"] : ""
                    entryNote := entry.Has("note") ? entry["note"] : ""
                } else {
                    entryName := entry
                }
                if (entryName != "" && StrCompare(nameWithTag, entryName, false) == 0) {
                    isBlacklisted := true
                    blacklistNote := entryNote
                }
            }
        }
        
        playerMap := Map(
            "puuid", puuid,
            "nameWithTag", nameWithTag,
            "gameName", gameName,
            "tagLine", tagLine,
            "championId", champId,
            "championName", champName,
            "isMe", isMe,
            "isBlacklisted", isBlacklisted,
            "blacklistNote", blacklistNote,
            "cellId", cellId,
            "position", position,
            "spell1Id", spell1Id,
            "spell2Id", spell2Id
        )
        teamArr.Push(playerMap)
    }
    
    ; Build bench list
    benchArr := Array()
    benchEnabled := session.Has("benchEnabled") && (session["benchEnabled"] = true || session["benchEnabled"] = "true")
    if (benchEnabled) {
        benchResult := GetBenchFromSession(session)
        if (benchResult["data"] != "") {
            preferredIdsArray := config.Has("autoPickBenchIds") ? config["autoPickBenchIds"] : Array()
            preferredIds := Map()
            for id in preferredIdsArray {
                preferredIds[id] := true
            }
            
            for entry in benchResult["data"] {
                cid := GetBenchChampId(entry)
                cname := GetChampionName(cid)
                isTarget := preferredIds.Has(cid)
                benchArr.Push(Map("id", cid, "name", cname, "isTarget", isTarget ? true : false))
            }
        }
    }
    
    if (myTeamId == 0 && teamArr.Length > 0) {
        firstPlayer := session["myTeam"][1]
        firstPlayerCell := firstPlayer.Has("cellId") ? firstPlayer["cellId"] : 0
        firstPlayerTeam := firstPlayer.Has("team") ? firstPlayer["team"] : 0
        if (firstPlayerTeam == 0) {
            if (firstPlayerCell < session["myTeam"].Length) {
                myTeamId := 1
            } else {
                myTeamId := 2
            }
        } else {
            myTeamId := firstPlayerTeam
        }
    }
    
    payload := Map(
        "players", teamArr,
        "bench", benchArr,
        "benchEnabled", benchEnabled,
        "myCellId", session.Has("localPlayerCellId") ? session["localPlayerCellId"] : -1,
        "myTeamId", myTeamId
    )
    
    try {
        MyWindow.ExecuteScriptAsync("updateChampSelectDraft(" JSON.Dump(payload) ")")
    }
}

GetSummonerNameByPuuid(puuid) {
    global summonerCache
    if (!IsSet(summonerCache)) {
        global summonerCache := Map()
    }
    if (summonerCache.Has(puuid)) {
        return summonerCache[puuid]
    }
    summoner := LeagueAPI.GetSummonerByPuuid(puuid)
    if (IsObject(summoner) && summoner.Has("gameName")) {
        nameWithTag := summoner["gameName"] "#" summoner["tagLine"]
        if (nameWithTag != "#") {
            summonerCache[puuid] := nameWithTag
            return nameWithTag
        }
    }
    return ""
}

ResetChampSelectHelper() {
    global lastSessionId, champLobbyNames, warnedNoIds, warnedEmpty, bypassAutoPick, lastSentChampId
    lastSessionId := ""
    champLobbyNames := Array()
    warnedNoIds := false
    warnedEmpty := false
    bypassAutoPick := false
    lastSentChampId := 0
    try MyWindow.ExecuteScriptAsync("onLobbyCleared()")
    try MyWindow.ExecuteScriptAsync("clearBenchDisplay()")
    try MyWindow.ExecuteScriptAsync("clearChampSelectDraft()")
}

ProcessChampMessages(session) {
    global lastSentChampId
    
    if (!session.Has("chatDetails"))
        return
        
    conversationId := session["chatDetails"].Has("multiUserChatId") ? session["chatDetails"]["multiUserChatId"] : ""
    if (conversationId == "")
        return
        
    myInfo := GetMyChampInfo(session)
    champId := myInfo["championId"]
    champName := myInfo["championName"]
    
    if (champId == 0) {
        lastSentChampId := 0
        return
    }
    
    if (champId == lastSentChampId) {
        return
    }
    
    messagesFilePath := "champMessages.json"
    if (!FileExist(messagesFilePath)) {
        return
    }
    
    try {
        fileContent := FileRead(messagesFilePath, "UTF-8")
        if (fileContent == "")
            return
        messagesData := JSON.Load(fileContent)
        if (!IsObject(messagesData))
            return
            
        matchedKey := ""
        champNameLower := Format("{:L}", champName)
        champIdStr := String(champId)
        
        for k, v in messagesData {
            kLower := Format("{:L}", String(k))
            if (kLower == champNameLower || kLower == champIdStr) {
                matchedKey := k
                break
            }
        }
        
        if (matchedKey != "") {
            messagesList := messagesData[matchedKey]
            
            if (Type(messagesList) == "Array") {
                combinedMsg := ""
                for msg in messagesList {
                    combinedMsg .= (combinedMsg == "" ? "" : " ") msg
                }
                LeagueAPI.SendChatMessage(conversationId, combinedMsg)
            } else if (Type(messagesList) == "String") {
                LeagueAPI.SendChatMessage(conversationId, messagesList)
            }
            
            lastSentChampId := champId
            LogToWeb("Sent custom chat message for " champName, "success")
        }
    } catch Error as e {
        LogToWeb("Error processing custom champ messages: " e.Message, "error")
    }
}
