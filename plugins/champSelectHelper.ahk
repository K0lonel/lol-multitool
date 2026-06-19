#Requires AutoHotkey v2.0
#Include ../lol.ahk
plugins.Push(champSelectHelper)

global champLobbyNames := Array()
global lastSessionId := ""
global warnedNoIds := false
global warnedEmpty := false
global bypassAutoPick := false

champSelectHelper() {
    global config, gameflow
    static wasInChampSelect := false
    static sessionFailCount := 0
    
    if (gameflow == "ChampSelect") {
        if (!wasInChampSelect) {
            wasInChampSelect := true
            sessionFailCount := 0
            LogToWeb("Entered Champion Select lobby. Active Draft Companion initialized.", "info")
            ; Log sniper status on entry
            if (config.Has("autoPickBenchEnabled") && config["autoPickBenchEnabled"]) {
                targetNames := GetTargetChampNames()
                LogToWeb("Bench Sniper: ARMED on lobby entry. Targets: " targetNames, "success")
            } else {
                LogToWeb("Bench Sniper: DISABLED on lobby entry. Toggle the sniper ON to activate.", "warning")
            }
        }
        try {
            session := APICall("GET", "/lol-champ-select/v1/session")
            if (IsObject(session) && !session.Has("error")) {
                sessionFailCount := 0
                ScanChampSelectLobby(session)
                ProcessBenchSwaps(session)
            } else if (IsObject(session) && session.Has("error")) {
                sessionFailCount++
                errCode := session.Has("status") ? session["status"] : "?"
                errType := session.Has("error") ? session["error"] : "?"
                if (errType == "Offline") {
                    if (sessionFailCount == 1)
                        LogToWeb("Bench Sniper: LCU went offline during ChampSelect.", "error")
                } else if (errCode == 404) {
                    if (sessionFailCount <= 3)
                        LogToWeb("Bench Sniper: Session not ready yet (404). Waiting... (attempt " sessionFailCount ")", "debug")
                    else if (sessionFailCount == 10)
                        LogToWeb("Bench Sniper: Session still returning 404 after 10 attempts.", "warning")
                } else {
                    LogToWeb("Bench Sniper: Session query failed — HTTP " errCode " (" errType "). Attempt " sessionFailCount, "warning")
                }
            } else {
                sessionFailCount++
                LogToWeb("Bench Sniper: Session returned unexpected data type: " Type(session), "error")
            }
        } catch Error as e {
            LogToWeb("ChampSelect Error: " e.Message " at line " e.Line, "error")
        }
    } else {
        if (wasInChampSelect) {
            wasInChampSelect := false
            sessionFailCount := 0
            LogToWeb("Exited Champion Select lobby.", "info")
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
    
    LogToWeb("Draft Companion: Scraping team lobby participants...", "info")
    for player in session["myTeam"] {
        puuid := player["puuid"]
        summoner := APICall("GET", "/lol-summoner/v1/summoners/by-puuid/" puuid)
        if (IsObject(summoner) && summoner.Has("gameName")) {
            nameWithTag := summoner["gameName"] "#" summoner["tagLine"]
            champLobbyNames.Push(nameWithTag)
        }
    }
    
    if (champLobbyNames.Length > 0) {
        LogToWeb("Draft Companion: Successfully scraped lobby players: " JSON.Dump(champLobbyNames), "success")
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
        LogToWeb("Bench Sniper: Session keys: " DumpSessionKeys(session), "debug")
    }
    
    ; --- Gate: Is the bench actually enabled in this queue session? ---
    benchEnabled := session.Has("benchEnabled") && (session["benchEnabled"] = true || session["benchEnabled"] = "true")
    if (!benchEnabled) {
        try MyWindow.ExecuteScriptAsync("clearBenchDisplay()")
        if (Mod(tickCount, 10) == 1) {
            LogToWeb("Bench Sniper: [SKIP] Bench is not enabled in this session.", "debug")
        }
        return
    }
    
    ; --- Retrieve bench data and player info for the visual bench (independent of sniper toggle) ---
    benchResult := GetBenchFromSession(session)
    myInfo := GetMyChampInfo(session)

    if (benchResult["data"] != "") {
        SendBenchToFrontend(benchResult["data"], benchResult["key"], myInfo)
    } else {
        try MyWindow.ExecuteScriptAsync("clearBenchDisplay()")
    }
    
    ; --- Gate 0: Has the user manually bypassed the auto-picker? ---
    global bypassAutoPick
    if (bypassAutoPick) {
        if (Mod(tickCount, 10) == 1) {
            LogToWeb("Bench Sniper: [SKIP] bypassAutoPick is True (manual override active).", "debug")
        }
        return
    }
    
    ; --- Gate 1: Is the sniper enabled? ---
    sniperHasKey := config.Has("autoPickBenchEnabled")
    sniperValue := sniperHasKey ? config["autoPickBenchEnabled"] : "N/A"
    
    if (!sniperHasKey || !config["autoPickBenchEnabled"]) {
        if (Mod(tickCount, 10) == 1) {
            LogToWeb("Bench Sniper: [SKIP] Sniper is OFF (autoPickBenchEnabled=" sniperValue "). Enable it to activate.", "debug")
        }
        return
    }
    
    ; --- Gate 2: Check if bench data was missing ---
    if (benchResult["data"] == "") {
        if (Mod(tickCount, 10) == 1) {
            LogToWeb("Bench Sniper: [SKIP] No bench champions found. Error: " benchResult["error"], "debug")
        }
        return
    }
    
    benchData := benchResult["data"]
    benchKeyName := benchResult["key"]
    
    ; Log target configuration info periodically
    if (Mod(tickCount, 10) == 1) {
        targetsList := config.Has("autoPickBenchIds") ? DumpPreferredRaw() : "N/A"
        LogToWeb("Bench Sniper Check: tickCount=" tickCount ", benchCount=" benchData.Length ", targets=" targetsList, "debug")
    }
    
    ; --- Gate 3: Do we have target champion IDs configured? ---
    if (!config.Has("autoPickBenchIds") || !IsObject(config["autoPickBenchIds"])) {
        if (!warnedNoIds) {
            LogToWeb("Bench Sniper: [SKIP] Target IDs config missing. Has key=" config.Has("autoPickBenchIds"), "warning")
            warnedNoIds := true
        }
        return
    }
        
    preferredIdsArray := config["autoPickBenchIds"]
    if (preferredIdsArray.Length == 0) {
        if (!warnedEmpty) {
            LogToWeb("Bench Sniper: [SKIP] Target list is empty. Add champions to snipe.", "warning")
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
            LogToWeb("Bench Sniper: Already holding target " myInfo["championName"] " (ID:" myChampId "). No swap needed.", "success")
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
            LogToWeb("Bench Sniper: Checking bench champ " champName " (ID:" champId ") against targets. Match result=" (matched ? "TRUE" : "FALSE"), "debug")
        }
        
        if (matched) {
            LogToWeb("Bench Sniper: Target MATCHED! Attempting swap for " champName " (ID:" champId ")...", "warning")
            res := APICall("POST", "/lol-champ-select/v1/session/bench/swap/" champId)
            
            LogToWeb("Bench Sniper: Swap API response received. Type=" Type(res) " isObject=" IsObject(res), "debug")
            
            if (IsObject(res) && res.Has("error")) {
                errStatus := res.Has("status") ? res["status"] : "?"
                errMsg := res.Has("error") ? res["error"] : "Unknown"
                LogToWeb("Bench Sniper: SWAP FAILED — " champName " — HTTP " errStatus " (" errMsg ")", "error")
            } else {
                LogToWeb("Bench Sniper: SWAP SENT for " champName " successfully. Verifying...", "success")
                ; Confirm swap
                try {
                    Sleep(300)
                    confirmSession := APICall("GET", "/lol-champ-select/v1/session")
                    if (IsObject(confirmSession) && !confirmSession.Has("error")) {
                        newInfo := GetMyChampInfo(confirmSession)
                        if (newInfo["championId"] == champId) {
                            LogToWeb("Bench Sniper: CONFIRMED — you now have " newInfo["championName"], "success")
                        } else {
                            LogToWeb("Bench Sniper: NOT CONFIRMED — expected " champName " but have " newInfo["championName"] " (ID:" newInfo["championId"] "). Server may have rejected swap.", "warning")
                        }
                    } else {
                        LogToWeb("Bench Sniper: Could not confirm — session re-fetch failed.", "warning")
                    }
                } catch Error as e {
                    LogToWeb("Bench Sniper: Could not confirm — " e.Message, "warning")
                }
            }
            
            lastBenchState := ""
            return
        }
    }
}

SendBenchToFrontend(benchData, benchKeyName, myInfo) {
    global config
    static lastSentState := ""
    
    ; Build state string for change detection
    stateStr := ""
    for entry in benchData {
        stateStr .= GetBenchChampId(entry) ","
    }
    stateStr .= "|" myInfo["championId"]
    
    if (stateStr == lastSentState)
        return
    lastSentState := stateStr
    
    ; Build JSON array of bench champ objects
    benchArr := Array()
    preferredIdsArray := config.Has("autoPickBenchIds") ? config["autoPickBenchIds"] : Array()
    preferredIds := Map()
    for id in preferredIdsArray {
        preferredIds[id] := true
    }
    
    for entry in benchData {
        cid := GetBenchChampId(entry)
        cname := GetChampionName(cid)
        isTarget := preferredIds.Has(cid)
        benchArr.Push(Map("id", cid, "name", cname, "isTarget", isTarget ? true : false))
    }
    
    payload := Map(
        "bench", benchArr,
        "myChampId", myInfo["championId"],
        "myChampName", myInfo["championName"]
    )
    
    try {
        MyWindow.ExecuteScriptAsync("updateBenchDisplay(" JSON.Dump(payload) ")")
    }
}

ResetChampSelectHelper() {
    global lastSessionId, champLobbyNames, warnedNoIds, warnedEmpty, bypassAutoPick
    lastSessionId := ""
    champLobbyNames := Array()
    warnedNoIds := false
    warnedEmpty := false
    bypassAutoPick := false
    try MyWindow.ExecuteScriptAsync("onLobbyCleared()")
    try MyWindow.ExecuteScriptAsync("clearBenchDisplay()")
}
