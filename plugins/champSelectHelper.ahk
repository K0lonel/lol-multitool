#Requires AutoHotkey v2.0
#Include ../lib/utilities.ahk
#Include ../lib/LCU.ahk
#Include ../lib/API.ahk

plugins.Push(champSelectHelper)

global champLobbyNames := Array()
global lastSessionId := ""
global warnedNoIds := false
global warnedEmpty := false

champSelectHelper() {
    global config, gameflow
    static wasInChampSelect := false
    
    if (gameflow == "ChampSelect") {
        if (!wasInChampSelect) {
            wasInChampSelect := true
            LogToWeb("Entered Champion Select lobby. Active Draft Companion initialized.", "info")
        }
        try {
            session := APICall("GET", "/lol-champ-select/v1/session")
            if (IsObject(session) && !session.Has("error")) {
                ScanChampSelectLobby(session)
                ProcessBenchSwaps(session)
            } else if (IsObject(session) && session.Has("error") && session["error"] != "Offline") {
                LogToWeb("Failed to query draft session data: HTTP " session["status"], "warning")
            }
        } catch Error as e {
            LogToWeb("ChampSelect Error: " e.Message " at line " e.Line, "error")
        }
    } else {
        if (wasInChampSelect) {
            wasInChampSelect := false
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
        MyWindow.ExecuteScript("onLobbyScraped(" JSON.Dump(champLobbyNames) ")")
    }
}

ProcessBenchSwaps(session) {
    global config, warnedNoIds, warnedEmpty
    if (!config.Has("autoPickBenchEnabled") || !config["autoPickBenchEnabled"])
        return
        
    if (!session.Has("bench") || !IsObject(session["bench"]) || Type(session["bench"]) != "Array" || session["bench"].Length == 0)
        return
        
    if (!config.Has("autoPickBenchIds") || !IsObject(config["autoPickBenchIds"])) {
        if (!warnedNoIds) {
            LogToWeb("Bench Sniper: Companion is enabled, but target champion IDs config is missing.", "warning")
            warnedNoIds := true
        }
        return
    }
        
    preferredIds := config["autoPickBenchIds"]
    if (preferredIds.Length == 0) {
        if (!warnedEmpty) {
            LogToWeb("Bench Sniper: Companion is enabled, but target champion list is empty.", "warning")
            warnedEmpty := true
        }
        return
    }
    
    ; Track bench state
    static lastBenchState := ""
    benchStateStr := ""
    for benchChamp in session["bench"] {
        benchStateStr .= benchChamp["championId"] ","
    }
    
    ; Only log when the bench actually changes to keep console clean
    if (benchStateStr != lastBenchState) {
        lastBenchState := benchStateStr
        
        benchNames := Array()
        for benchChamp in session["bench"] {
            benchNames.Push(GetChampionName(benchChamp["championId"]))
        }
        joinedBench := ""
        for name in benchNames {
            joinedBench .= (joinedBench == "" ? "" : ", ") name
        }
        LogToWeb("Bench Sniper: Team bench updated: [" joinedBench "]", "info")
    }
    
    for benchChamp in session["bench"] {
        champId := benchChamp["championId"]
        ; Compare both Integer and String forms to handle JSON type mismatches
        matched := HasVal(preferredIds, Integer(champId)) || HasVal(preferredIds, String(champId))
        if (matched) {
            champName := GetChampionName(champId)
            LogToWeb("Bench Sniper: Target MATCH found on bench! Swapping to: " champName "...", "warning")
            res := APICall("POST", "/lol-champ-select/v1/session/bench/swap/" champId)
            if (IsObject(res) && res.Has("error")) {
                LogToWeb("Bench Sniper: Swap failed for " champName ". Error code: " res["status"] " (" res["error"] ")", "error")
            } else {
                LogToWeb("Bench Sniper: Swapped to " champName " successfully!", "success")
            }
            return  ; Stop after first successful swap attempt
        }
    }
}

ResetChampSelectHelper() {
    global lastSessionId, champLobbyNames, warnedNoIds, warnedEmpty
    lastSessionId := ""
    champLobbyNames := Array()
    warnedNoIds := false
    warnedEmpty := false
    try MyWindow.ExecuteScript("onLobbyCleared()")
}
