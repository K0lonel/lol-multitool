#Requires AutoHotkey v2.0+
#SingleInstance Force
SetWorkingDir(A_ScriptDir)
global plugins := Array()

#Include lib/JSON.ahk
#Include lib/Config.ahk
#Include lib/API.ahk
#Include lib/LeagueAPI.ahk
#Include lib/WebView2/WebViewToo.ahk
#Include plugins/autoAccept.ahk
#Include plugins/autoReport.ahk
#Include plugins/champSelectHelper.ahk
#Include plugins/blacklist.ahk
#Include plugins/autoSkipPreEnd.ahk
#Include plugins/lootAssistant.ahk
#Include plugins/smartAutoHonorer.ahk
#Include plugins/killLeague.ahk

FileEncoding "UTF-8"
JSON.EscapeUnicode := False

if(!FileExist("history.json"))
    FileAppend("{}", "history.json")
global match_history_dic := JSON.Load(FileRead("history.json"))
global historyDirty := false
global historyVersion := 0
global friend_puuid := Map()
global reportList := ""
global reportQueue := Array()
global reportStatus := "Idle"
global championsLoaded := false
global championMap := Map()
global checkedGames := Map()
global autoHonorCompleted := false
global friendsCount := 0
global friendsOnline := 0
global recentWinRate := "--"
global sessionStartTime := A_TickCount
global cachedMatchesCount := 0
global totalPlayersLoggedCount := 0
global currentSearchQuery := ""
global lastHistoryVersion := -1
global lastQueueSize := -1

RecalculateHistoryStats() {
    global match_history_dic, cachedMatchesCount, totalPlayersLoggedCount
    cachedMatchesCount := match_history_dic.Count
    totalPlayers := 0
    for gameId, gameData in match_history_dic {
        if (IsObject(gameData) && gameData.Has("ReportedPlayers") && IsObject(gameData["ReportedPlayers"])) {
            totalPlayers += gameData["ReportedPlayers"].Length
        }
    }
    totalPlayersLoggedCount := totalPlayers
}
RecalculateHistoryStats()

; Load and initialize configuration
InitializeConfig()

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

; Enable browser extensions globally for all WebViewControls in this script quick and dirty
origNew := WebViewCtrl.Prototype.GetOwnPropDesc("__New").Call
WebViewCtrl.Prototype.DefineProp("__New", {Call: (self, settings := {}) => (
    settings.Options := { AreBrowserExtensionsEnabled: true },
    origNew(self, settings)
)})

EnsureExtension()
global MyWindow := WebViewGui("-Caption +Resize", "LoL-App")
extDir := A_ScriptDir "\Extensions\AdGuard-AdBlocker"
if (DirExist(extDir) && FileExist(extDir "\manifest.json")) {
    try {
        MyWindow.Profile.AddBrowserExtensionAsync(extDir)
    } catch Error as e {
        OutputDebug("Failed to load AdGuard extension: " e.Message "`n")
    }
} else {
    OutputDebug("AdGuard extension files are missing or incomplete. Extension loading skipped.`n")
}
MyWindow.OnEvent("Close", (*) => ExitApp())
OnExit(ExitSave)

; Register callbacks
MyWindow.AddCallBackToScript("updateConfig", UpdateConfigCallback)
MyWindow.AddCallBackToScript("Tooltip", WebTooltipEvent)
MyWindow.AddCallBackToScript("dodgeLobby", DodgeLobbyCallback)
MyWindow.AddCallBackToScript("triggerMassDisenchant", TriggerMassDisenchantCallback)
MyWindow.AddCallBackToScript("restartUX", RestartUXCallback)
MyWindow.AddCallBackToScript("benchSwap", BenchSwapCallback)
MyWindow.AddCallBackToScript("setSummonerSpells", SetSummonerSpellsCallback)
MyWindow.AddCallBackToScript("getRecentPlayers", GetRecentPlayersCallback)
MyWindow.AddCallBackToScript("requestHistoryTimeline", RequestHistoryTimelineCallback)
MyWindow.AddCallBackToScript("toggleCycleBench", ToggleCycleBenchCallback)
MyWindow.AddCallBackToScript("Close", CloseWindow)
MyWindow.AddCallBackToScript("DragWindow", DragWindow)
MyWindow.AddCallBackToScript("Minimize", MinimizeWindow)
MyWindow.AddCallBackToScript("Maximize", MaximizeWindow)
MyWindow.AddCallBackToScript("Reload", (*) => Reload())

; Map local Pages folder and navigate to index.html
MyWindow.BrowseFolder("Pages")
MyWindow.Navigate("index.html")

windowWidth := config.Has("windowWidth") ? config["windowWidth"] : 1200
windowHeight := config.Has("windowHeight") ? config["windowHeight"] : 800
MyWindow.Show("w" windowWidth " h" windowHeight " Center")

for plugin in plugins
    SetTimer(plugin, 1000)

global me := Map()
global friends := Array()
global gameflow := "None"
global match_history := Map()
global initConfigSent := false
global historyTimer := 30
global champTimer := 9
global meTimer := 10
global friendsTimer := 10
global lastGameflow := "INIT"
global wasLcuConnected := false
global lastDashboardState := ""
RequestHistoryTimelineCallback(WebView, searchQuery) {
    PushHistoryTimeline(searchQuery)
}

PushHistoryTimeline(searchQuery := unset) {
    global match_history_dic, MyWindow, currentSearchQuery
    if (IsSet(searchQuery)) {
        currentSearchQuery := searchQuery
    }
    
    queryLower := Format("{:L}", currentSearchQuery)
    filteredItems := Array()
    
    for gameId, gameData in match_history_dic {
        if (!IsObject(gameData) || !gameData.Has("Timestamp"))
            continue
            
        if (queryLower != "") {
            matchFound := false
            if (InStr(Format("{:L}", gameId), queryLower)) {
                matchFound := true
            } else {
                if (gameData.Has("ReportedPlayers") && IsObject(gameData["ReportedPlayers"])) {
                    for player in gameData["ReportedPlayers"] {
                        if (InStr(Format("{:L}", player), queryLower)) {
                            matchFound := true
                            break
                        }
                    }
                }
            }
            if (!matchFound)
                continue
        }
        
        itemCopy := Map(
            "gameId", gameId,
            "Timestamp", gameData["Timestamp"]
        )
        if (gameData.Has("ReportedPlayers"))
            itemCopy["ReportedPlayers"] := gameData["ReportedPlayers"]
        else
            itemCopy["ReportedPlayers"] := Array()
            
        if (gameData.Has("DamageStats"))
            itemCopy["DamageStats"] := gameData["DamageStats"]
            
        filteredItems.Push(itemCopy)
    }
    
    ; Sort filteredItems by Timestamp descending
    SortTimeline(filteredItems)
    
    ; Limit items: 15 for empty query, 50 for search
    limit := (queryLower == "") ? 15 : 50
    slicedItems := Array()
    loopMin := (filteredItems.Length < limit) ? filteredItems.Length : limit
    Loop loopMin {
        slicedItems.Push(filteredItems[A_Index])
    }
    
    try {
        MyWindow.ExecuteScriptAsync("updateHistoryTimeline(" JSON.Dump(slicedItems) ")")
    }
}

SortTimeline(arr) {
    if (arr.Length <= 1)
        return arr
    QuickSortTimeline(arr, 1, arr.Length)
    return arr
}

QuickSortTimeline(arr, left, right) {
    if (left >= right)
        return
    pivotIdx := Random(left, right)
    pivotVal := arr[pivotIdx]["Timestamp"]
    
    ; Swap pivot to right
    temp := arr[pivotIdx]
    arr[pivotIdx] := arr[right]
    arr[right] := temp
    
    i := left
    j := left
    while (j < right) {
        if (arr[j]["Timestamp"] > pivotVal) {
            temp := arr[i]
            arr[i] := arr[j]
            arr[j] := temp
            i++
        }
        j++
    }
    
    ; Swap pivot back to i
    temp := arr[i]
    arr[i] := arr[right]
    arr[right] := temp
    
    QuickSortTimeline(arr, left, i - 1)
    QuickSortTimeline(arr, i + 1, right)
}

loop {
    historyTimer++
    sessionSecs := (A_TickCount - sessionStartTime) // 1000
    sessionTime := FormatSessionTime(sessionSecs)
    
    ; Determine connection status in a fast and CPU-efficient way
    lcuConnected := false
    if (LCU.Token != "" || LCU.Initialize()) {
        lcuConnected := true
    }
    
    if (lcuConnected && !wasLcuConnected) {
        wasLcuConnected := true
        championsLoaded := false
        initConfigSent := false
        champTimer := 9  ; Force quick champion load attempt
        meTimer := 10
        friendsTimer := 10
        LogToWeb("LCU connection established. Syncing active configuration and inventory...", "success")
    } else if (!lcuConnected && wasLcuConnected) {
        wasLcuConnected := false
        championsLoaded := false
        LogToWeb("LCU connection lost. Standing by...", "warning")
    }
    
    if (lcuConnected) {
        meTimer++
        friendsTimer++

        ; 1. Profile check (every 10 seconds or if missing)
        if (meTimer >= 10 || !me.Has("lol")) {
            meTimer := 0
            try {
                tempMe := LeagueAPI.GetCurrentSummoner()
                if (IsObject(tempMe) && (tempMe.Has("gameName") || tempMe.Has("displayName"))) {
                    gameName := tempMe.Has("gameName") ? tempMe["gameName"] : tempMe["displayName"]
                    tagLine := tempMe.Has("tagLine") ? tempMe["tagLine"] : ""
                    summonerLevel := tempMe.Has("summonerLevel") ? tempMe["summonerLevel"] : 0
                    iconId := tempMe.Has("profileIconId") ? tempMe["profileIconId"] : 29
                    puuid := tempMe.Has("puuid") ? tempMe["puuid"] : ""
                    summonerId := tempMe.Has("summonerId") ? tempMe["summonerId"] : 0
                    
                    global me := Map("lol", Map(
                        "gameName", gameName,
                        "tagLine", tagLine,
                        "summonerLevel", summonerLevel,
                        "iconId", iconId,
                        "puuid", puuid,
                        "summonerId", summonerId,
                        "friendsCount", friendsCount,
                        "friendsOnline", friendsOnline,
                        "recentWinRate", recentWinRate
                    ))
                } else {
                    global me := Map()
                }
            } catch {
                global me := Map()
            }
        }
        
        ; 2. Friends check (every 10 seconds)
        if (friendsTimer >= 10) {
            friendsTimer := 0
            try {
                tempFriends := LeagueAPI.GetFriends()
                if (Type(tempFriends) == "Array") {
                    global friends := tempFriends
                    global friendsCount := friends.Length
                    tempOnline := 0
                    for index, friend in friends {
                        if (friend.Has("availability") && friend["availability"] != "offline") {
                            tempOnline++
                        }
                    }
                    global friendsOnline := tempOnline
                    if (friends.Length != friend_puuid.Count) {
                        friend_puuid := Map()
                        for index, friend in friends
                            friend_puuid[friend["puuid"]] := true
                    }
                }
            } catch {
                global friends := Array()
            }
        }
        
        ; 3. Gameflow phase check (every 1 second)
        try {
            tempGameflow := LeagueAPI.GetGameflowPhase()
            if (Type(tempGameflow) == "String") {
                global gameflow := tempGameflow
            } else {
                global gameflow := ""
            }
        } catch {
            global gameflow := ""
        }
    } else {
        global me := Map()
        global friends := Array()
        global gameflow := ""
    }
    
    ; Track Gameflow phase transitions and connection status
    if (gameflow != lastGameflow) {
        if (gameflow != "") {
            LogToWeb("LCU Gameflow phase changed to: " gameflow, "info")
            if (gameflow == "EndOfGame") {
                if WinExist("ahk_exe LeagueClientUx.exe") {
                    LogToWeb("EndOfGame phase detected. Focusing League Client UX...", "info")
                    WinActivate("ahk_exe LeagueClientUx.exe")
                }
            }
        } else if (lastGameflow != "INIT" && lastGameflow != "") {
            LogToWeb("LCU connection lost or offline.", "error")
        }
        global lastGameflow := gameflow
    }
    
    ; 2. Match History & Stats (every 30 seconds, or 5 seconds if not yet loaded)
    forceStatsCheck := (lcuConnected && recentWinRate == "--")
    if (historyTimer >= 30 || (forceStatsCheck && historyTimer >= 5)) {
        historyTimer := 0
        if (lcuConnected) {
            try {
                tempHistory := LeagueAPI.GetCurrentSummonerMatches(0, 49)
                if (IsObject(tempHistory) && tempHistory.Has("games")) {
                    global match_history := tempHistory
                    
                    ; Calculate win rate of the last 10 games
                    if (IsObject(tempHistory["games"]) && tempHistory["games"].Has("games")) {
                        gamesArr := tempHistory["games"]["games"]
                        winsCount := 0
                        lossesCount := 0
                        validGamesCount := 0
                        
                        for index, game in gamesArr {
                            if (validGamesCount >= 20)
                                break
                                
                            ; Ignore custom games or practice tool
                            isCustom := (game.Has("gameType") && game["gameType"] == "CUSTOM_GAME") || (game.Has("queueId") && game["queueId"] == 0)
                            isPracticeTool := game.Has("gameMode") && game["gameMode"] == "PRACTICETOOL"
                            if (isCustom || isPracticeTool)
                                continue
                                
                            partId := 0
                            if (game.Has("participantIdentities")) {
                                for idx, identity in game["participantIdentities"] {
                                    if (identity.Has("player") && identity["player"].Has("puuid") && identity["player"]["puuid"] == puuid) {
                                        partId := identity.Has("participantId") ? identity["participantId"] : 0
                                        break
                                    }
                                }
                            }
                            
                            foundGameResult := false
                            if (partId > 0 && game.Has("participants")) {
                                for idx, participant in game["participants"] {
                                    if (participant.Has("participantId") && participant["participantId"] == partId) {
                                        if (participant.Has("stats") && participant["stats"].Has("win")) {
                                            if (participant["stats"]["win"]) {
                                                winsCount++
                                            } else {
                                                lossesCount++
                                            }
                                            foundGameResult := true
                                        }
                                        break
                                    }
                                }
                            }
                            
                            if (foundGameResult) {
                                validGamesCount++
                            }
                        }
                        
                        totalRecentGames := winsCount + lossesCount
                        if (totalRecentGames > 0) {
                            wrPercent := Round((winsCount / totalRecentGames) * 100)
                            global recentWinRate := String(wrPercent) "% (" String(winsCount) "W / " String(lossesCount) "L)"
                        } else {
                            global recentWinRate := "No Games"
                        }
                    } else {
                        global recentWinRate := "No Games"
                    }
                } else if (IsObject(tempHistory) && tempHistory.Has("error") && tempHistory["error"] != "Offline") {
                    LogToWeb("Failed to fetch match history: LCU returned error status " tempHistory["status"], "warning")
                }
            } catch Error as e {
                LogToWeb("Failed to fetch match history: " e.Message, "error")
            }
        }
    }
    
    ; 3. Execute Frontend Scripts & Champion Loading
    try {
        if (!initConfigSent) {
            MyWindow.ExecuteScriptAsync("initConfig(" JSON.Dump(config) ")")
            initConfigSent := true
            PushHistoryTimeline("")
            LogToWeb("App dashboard UI initialized.", "info")
            if (gameflow != "") {
                LogToWeb("LCU connected. Current phase: " gameflow, "success")
            } else {
                LogToWeb("LCU disconnected. Waiting for League client to start...", "warning")
            }
        }
        
        if (lcuConnected && !championsLoaded) {
            champTimer++
            if (champTimer >= 2) {
                champTimer := 0
                summonerId := (IsObject(me) && me.Has("lol") && me["lol"].Has("summonerId")) ? me["lol"]["summonerId"] : 0
                champs := LeagueAPI.GetChampionsMinimal(summonerId)
                if (Type(champs) == "Array" && champs.Length > 0) {
                    global championMap := Map()
                    for c in champs {
                        if (c.Has("id")) {
                            cId := Integer(c["id"])
                            championMap[cId] := c
                            championMap[String(cId)] := c
                        }
                    }
                    LogToWeb("Successfully loaded " champs.Length " champions into AHK cache.", "success")
                    MyWindow.ExecuteScriptAsync("loadChampsFromLCU(" JSON.Dump(champs) ")")
                    championsLoaded := true
                }
            }
        }
        
        ; Flush pending history writes to disk if dirty (debounced)
        if (historyDirty) {
            SaveHistory()
        }

        ; Only update the dashboard UI when data actually changes using lightweight state comparison
        meSummonerId := (me.Has("lol") && me["lol"].Has("gameName")) ? me["lol"]["gameName"] : ""
        currentDashboardState := meSummonerId "|" gameflow "|" historyVersion "|" reportQueue.Length "|" reportStatus
        if (currentDashboardState != lastDashboardState) {
            lastDashboardState := currentDashboardState
            MyWindow.ExecuteScriptAsync("updateDashboard(" JSON.Dump(me) ", '" gameflow "', " reportQueue.Length ", '" reportStatus "', " cachedMatchesCount ", " totalPlayersLoggedCount ")")
        }

        ; Monitor history changes to push timeline updates
        if (historyVersion != lastHistoryVersion) {
            lastHistoryVersion := historyVersion
            PushHistoryTimeline()
        }

        ; Monitor reportQueue state to refresh recent players when reports finish
        if (reportQueue.Length == 0 && lastQueueSize > 0) {
            try GetRecentPlayersCallback(MyWindow)
        }
        lastQueueSize := reportQueue.Length
    } catch Error as e {
        LogToWeb("Error in main loop script execution: " e.Message, "error")
    }
    
    sleep 1000
}
return
#HotIf IsSet(MyWindow) && WinActive("ahk_id " MyWindow.Hwnd)
$^q::ExitApp
$^r::Reload
$^d::MyWindow.OpenDevToolsWindow()
#HotIf
ExitSave(ExitReason := "", ExitCode := ""){
    global MyWindow, config
    if (IsSet(MyWindow)) {
        try {
            minMaxState := WinGetMinMax("ahk_id " MyWindow.Hwnd)
            if (minMaxState == 0) {
                MyWindow.GetPos(,, &wW, &wH)
                config["windowWidth"] := wW
                config["windowHeight"] := wH
            }
        }
    }
    SaveConfig()
    SaveHistory(true)
}

CloseWindow(WebView) {
    ExitApp()
}

DragWindow(WebView) {
    DllCall("ReleaseCapture")
    PostMessage(0x0112, 0xF012, 0,, "ahk_id " WebView.Hwnd)
}

MinimizeWindow(WebView) {
    WebView.Minimize()
}

MaximizeWindow(WebView) {
    if (DllCall("IsZoomed", "UPtr", WebView.Hwnd)) {
        WebView.Restore()
    } else {
        WebView.Maximize()
    }
}

UpdateConfigCallback(WebView, key, value) {
    global config, killLeagueEnabled
    if (key == "killLeagueEnabled") {
        killLeagueEnabled := (value == "true" || value = True)
        LogToWeb("Config updated: " key " -> " (killLeagueEnabled ? "True" : "False"), "debug")
        return
    }
    if (key == "reportCategories" || key == "autoPickBenchIds" || key == "favoriteChampIds" || key == "blacklist") {
        config[key] := JSON.Load(value)
    } else if (key == "acceptDelay") {
        config[key] := Number(value)
    } else if (value == "true" || value = True) {
        config[key] := True
    } else if (value == "false" || value = False) {
        config[key] := False
    } else {
        config[key] := value
    }
    SaveConfig()
    
    ; Log config updates to system logs console
    logVal := value
    if (key == "autoPickBenchIds" || key == "favoriteChampIds") {
        try {
            ids := JSON.Load(value)
            names := Array()
            for id in ids {
                names.Push(GetChampionName(id))
            }
            joined := ""
            for name in names {
                joined .= (joined == "" ? "" : ", ") name
            }
            logVal := "[" joined "]"
        } catch {
            logVal := value
        }
    }
    LogToWeb("Config updated: " key " -> " logVal, "debug")
}


WebTooltipEvent(WebView, Msg) {
    ToolTip(Msg)
    SetTimer((*) => ToolTip(), -1500)
}

ToggleCycleBenchCallback(WebView, enabledVal) {
    global cycleBenchEnabled, cycledChampIds
    cycleBenchEnabled := (enabledVal == "true" || enabledVal = True)
    cycledChampIds := Map()
    LogToWeb("Bench Cycling " . (cycleBenchEnabled ? "ENABLED" : "DISABLED") . ".", "info")
}

DodgeLobbyCallback(WebView) {
    LogToWeb("Dodge Lobby: Sending API dodge requests to LCU...", "warning")
    
    ; 1. Gameflow session dodge endpoint
    resDodge := LeagueAPI.DodgeGameflowSession()
    
    ; 2. Lobby session quit endpoint
    resQuit := LeagueAPI.QuitLobbySession()
    
    ; 3. LCDS proxy dodge endpoint
    resLcds := LeagueAPI.LcdsDodge()
    
    LogToWeb("Dodge Lobby: Sent dodge API calls to LCU without closing client.", "success")
}

TriggerMassDisenchantCallback(WebView) {
    LogToWeb("Mass Disenchant: Initiated disenchanting...", "info")
    RunMassDisenchant(false)
}

RestartUXCallback(WebView) {
    LogToWeb("Restart UX: Requesting League client UX restart...", "warning")
    res := LeagueAPI.RestartUX()
    if (IsObject(res) && res.Has("error")) {
        errStatus := res.Has("status") ? res["status"] : "?"
        errMsg := res.Has("error") ? res["error"] : "Unknown"
        LogToWeb("Restart UX: FAILED — HTTP " errStatus " (" errMsg ")", "error")
    } else {
        LogToWeb("Restart UX: Successfully sent UX restart command.", "success")
    }
}

BenchSwapCallback(WebView, champId) {
    global bypassAutoPick
    champIdInt := Integer(champId)
    champName := GetChampionName(champIdInt)
    if (!bypassAutoPick) {
        bypassAutoPick := true
        LogToWeb("User picked a champ (" champName ") so the auto sniper wont try to overwrite user decision", "success")
    } else {
        LogToWeb("Manual Swap: User requested swap to " champName " (ID:" champIdInt ")", "info")
    }
    res := LeagueAPI.SwapBenchChampion(champIdInt)
    if (IsObject(res) && res.Has("error")) {
        errStatus := res.Has("status") ? res["status"] : "?"
        errMsg := res.Has("error") ? res["error"] : "Unknown"
        LogToWeb("Manual Swap: FAILED for " champName " — HTTP " errStatus " (" errMsg ")", "error")
    }
}

SetSummonerSpellsCallback(WebView, spell1Id, spell2Id) {
    LogToWeb("Summoner Spells: Swapping spells to spell1=" spell1Id ", spell2=" spell2Id "...", "info")
    body := '{"spell1Id":' spell1Id ',"spell2Id":' spell2Id '}'
    res := LeagueAPI.UpdateMySelection(body)
    if (IsObject(res) && res.Has("error")) {
        errStatus := res.Has("status") ? res["status"] : "?"
        errMsg := res.Has("error") ? res["error"] : "Unknown"
        LogToWeb("Summoner Spells: Failed to change spells. HTTP " errStatus " (" errMsg ")", "error")
    } else {
        LogToWeb("Summoner Spells: Spells updated successfully!", "success")
    }
}

LogToWeb(msg, logType := "info", silentSetting := "") {
    global config, MyWindow, initConfigSent
    
    isSilent := false
    if (Type(silentSetting) == "String" && silentSetting != "") {
        if (IsSet(config) && config.Has(silentSetting)) {
            isSilent := config[silentSetting]
        }
    } else if (silentSetting) {
        isSilent := true
    }
    
    if (isSilent)
        return

    if (IsSet(MyWindow) && initConfigSent) {
        try {
            cleanMsg := StrReplace(msg, "\", "\\")
            cleanMsg := StrReplace(cleanMsg, "'", "\'")
            cleanMsg := StrReplace(cleanMsg, "`n", " ")
            cleanMsg := StrReplace(cleanMsg, "`r", "")
            MyWindow.ExecuteScriptAsync("logSystemMessage('" cleanMsg "', '" logType "')")
        } catch {
            ; Ignore frontend log call failures
        }
    }
}

GetChampionName(id) {
    global championMap
    if (!IsSet(championMap) || !IsObject(championMap))
        return "ID " id
    
    intId := Integer(id)
    if (championMap.Has(intId)) {
        val := championMap[intId]
        if (IsObject(val) && val.Has("name"))
            return val["name"]
        return val
    }
    
    strId := String(intId)
    if (championMap.Has(strId)) {
        val := championMap[strId]
        if (IsObject(val) && val.Has("name"))
            return val["name"]
        return val
    }
    
    return "ID " intId
}

SaveHistory(force := false) {
    global match_history_dic, historyDirty
    if (!historyDirty && !force)
        return
    try {
        fileObj := FileOpen("history.json", "w", "UTF-8")
        fileObj.Write(JSON.Dump(match_history_dic, True))
        fileObj.Close()
        historyDirty := false
    } catch Error as e {
        LogToWeb("Failed to save history.json to disk: " e.Message, "error")
    }
}

HasHistoryGame(gameId) {
    global match_history_dic
    return match_history_dic.Has(gameId)
}

GetHistoryGame(gameId) {
    global match_history_dic
    if (match_history_dic.Has(gameId))
        return match_history_dic[gameId]
    return ""
}

SetHistoryGame(gameId, value) {
    global match_history_dic, historyDirty, historyVersion
    match_history_dic[gameId] := value
    historyDirty := true
    historyVersion++
    RecalculateHistoryStats()
}

FormatSessionTime(seconds) {
    hh := seconds // 3600
    mm := (seconds // 60) - (hh * 60)
    ss := Mod(seconds, 60)
    
    timeStr := ""
    if (hh > 0) {
        timeStr .= Format("{:02d}", hh) ":"
    }
    timeStr .= Format("{:02d}", mm) ":" Format("{:02d}", ss)
    return timeStr
}

EnsureExtension() {
    extDir := A_ScriptDir "\Extensions\AdGuard-AdBlocker"
    if (!DirExist(extDir) || !FileExist(extDir "\manifest.json")) {
        if (!DirExist(A_ScriptDir "\Extensions")) {
            DirCreate(A_ScriptDir "\Extensions")
        }
        zipFile := A_ScriptDir "\Extensions\temp_adguard.zip"
        
        ; Download pre-built minified AdGuard extension from official GitHub Release (v5.4.3.1)
        downloadUrl := "https://github.com/AdguardTeam/AdguardBrowserExtension/releases/download/v5.4.3.1/edge.zip"
        
        try {
            Download(downloadUrl, zipFile)
        } catch Error as e {
            MsgBox("Failed to download AdGuard extension: " e.Message "`n`nPlease ensure you have an active internet connection.", "Download Error", 48)
            return
        }
        
        ; Extract the downloaded zip file using PowerShell Expand-Archive
        ; Note: paths are single-quoted within PowerShell command to support spaces in directory names
        exitCode := 0
        try {
            exitCode := RunWait("powershell.exe -Command Expand-Archive -Path '" zipFile "' -DestinationPath '" extDir "' -Force", , "Hide")
        } catch Error as e {
            MsgBox("Failed to launch PowerShell for extraction: " e.Message, "Extraction Error", 48)
        }
        
        ; Clean up the zip file
        if (FileExist(zipFile)) {
            FileDelete(zipFile)
        }
        
        ; Verify extraction was successful
        if (exitCode != 0 || !FileExist(extDir "\manifest.json")) {
            if (DirExist(extDir)) {
                DirDelete(extDir, true) ; Clean up incomplete folder so we try again next time
            }
            MsgBox("Failed to extract AdGuard extension correctly. Please try restarting the application.", "Extraction Error", 48)
        }
    }
}