#Requires AutoHotkey v2.0+
#SingleInstance Force
SetWorkingDir(A_ScriptDir)
global plugins := Array()

#Include lib/JSON.ahk
#Include lib/API.ahk
#Include lib/WebView2/WebViewToo.ahk
#Include plugins/autoAccept.ahk
#Include plugins/autoReport.ahk
#Include plugins/champSelectHelper.ahk
#Include plugins/blacklist.ahk
#Include plugins/autoSkipPreEnd.ahk
#Include plugins/lootAssistant.ahk
#Include plugins/smartAutoHonorer.ahk

FileEncoding "UTF-8"
JSON.EscapeUnicode := False

if(!FileExist("history.json"))
    FileAppend("{}", "history.json")
global match_history_dic := JSON.Load(FileRead("history.json"))
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

; Load or create configuration
if(!FileExist("config.json")) {
    defaultConfig := Map(
        "autoAccept", True,
        "autoReport", True,
        "acceptDelay", 0,
        "reportCategories", ["LEAVING_AFK", "ASSISTING_ENEMY_TEAM", "THIRD_PARTY_TOOLS", "RANK_MANIPULATION", "BOTTING", "VERBAL_ABUSE", "INAPPROPRIATE_NAME"],
        "reportComment", "tried to lose",
        "autoPickBenchEnabled", False,
        "autoPickBenchIds", Array(),
        "favoriteChampIds", Array(),
        "foldSniper", False,
        "foldAccept", False,
        "foldReport", False,
        "blacklistEnabled", True,
        "blacklist", Array(),
        "foldBlacklist", False,
        "autoDisenchantChampionsEnabled", False,
        "autoDisenchantWardsEnabled", False,
        "autoHonorerEnabled", False,
        "autoSkipPreEndEnabled", False,
        "foldDisenchant", False,
        "foldHonorer", False,
        "foldSkipPreEnd", False,
        "autoAcceptSilent", False,
        "autoReportSilent", False,
        "autoSkipPreEndSilent", False,
        "blacklistSilent", False,
        "champSelectHelperSilent", False,
        "autoHonorerSilent", False,
        "disenchantSilent", False
    )
    FileAppend(JSON.Dump(defaultConfig, True), "config.json")
}
global config := JSON.Load(FileRead("config.json"))
if (!config.Has("favoriteChampIds")) {
    config["favoriteChampIds"] := Array()
    SaveConfig()
}
if (!config.Has("reportComment")) {
    config["reportComment"] := "tried to lose"
    SaveConfig()
}
if (!config.Has("foldSniper")) {
    config["foldSniper"] := False
    SaveConfig()
}
if (!config.Has("foldAccept")) {
    config["foldAccept"] := False
    SaveConfig()
}
if (!config.Has("foldReport")) {
    config["foldReport"] := False
    SaveConfig()
}
if (!config.Has("blacklistEnabled")) {
    config["blacklistEnabled"] := True
    SaveConfig()
}
if (!config.Has("blacklist")) {
    config["blacklist"] := Array()
    SaveConfig()
}
if (!config.Has("foldBlacklist")) {
    config["foldBlacklist"] := False
    SaveConfig()
}
if (!config.Has("autoDisenchantChampionsEnabled")) {
    config["autoDisenchantChampionsEnabled"] := False
    SaveConfig()
}
if (!config.Has("autoDisenchantWardsEnabled")) {
    config["autoDisenchantWardsEnabled"] := False
    SaveConfig()
}
if (!config.Has("autoHonorerEnabled")) {
    config["autoHonorerEnabled"] := False
    SaveConfig()
}
if (!config.Has("autoSkipPreEndEnabled")) {
    config["autoSkipPreEndEnabled"] := False
    SaveConfig()
}
if (!config.Has("foldDisenchant")) {
    config["foldDisenchant"] := False
    SaveConfig()
}
if (!config.Has("foldHonorer")) {
    config["foldHonorer"] := False
    SaveConfig()
}
if (!config.Has("foldSkipPreEnd")) {
    config["foldSkipPreEnd"] := False
    SaveConfig()
}
if (!config.Has("autoAcceptSilent")) {
    config["autoAcceptSilent"] := False
    SaveConfig()
}
if (!config.Has("autoReportSilent")) {
    config["autoReportSilent"] := False
    SaveConfig()
}
if (!config.Has("autoSkipPreEndSilent")) {
    config["autoSkipPreEndSilent"] := False
    SaveConfig()
}
if (!config.Has("blacklistSilent")) {
    config["blacklistSilent"] := False
    SaveConfig()
}
if (!config.Has("champSelectHelperSilent")) {
    config["champSelectHelperSilent"] := False
    SaveConfig()
}
if (!config.Has("autoHonorerSilent")) {
    config["autoHonorerSilent"] := False
    SaveConfig()
}
if (!config.Has("disenchantSilent")) {
    config["disenchantSilent"] := False
    SaveConfig()
}

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

; Enable browser extensions globally for all WebViewControls in this script quick and dirty
origNew := WebViewCtrl.Prototype.GetOwnPropDesc("__New").Call
WebViewCtrl.Prototype.DefineProp("__New", {Call: (self, settings := {}) => (
    settings.Options := { AreBrowserExtensionsEnabled: true },
    origNew(self, settings)
)})

global MyWindow := WebViewGui("-Caption +Resize", "LoL-App")
try {
    MyWindow.Profile.AddBrowserExtensionAsync(A_ScriptDir "\Extensions\AdGuard-AdBlocker")
} catch Error as e {
    OutputDebug("Failed to load AdGuard extension: " e.Message "`n")
}
MyWindow.OnEvent("Close", (*) => ExitApp())
OnExit(ExitSave)

; Register callbacks
MyWindow.AddCallBackToScript("updateConfig", UpdateConfigCallback)
MyWindow.AddCallBackToScript("Tooltip", WebTooltipEvent)
MyWindow.AddCallBackToScript("dodgeLobby", DodgeLobbyCallback)
MyWindow.AddCallBackToScript("triggerMassDisenchant", TriggerMassDisenchantCallback)
MyWindow.AddCallBackToScript("benchSwap", BenchSwapCallback)
MyWindow.AddCallBackToScript("setSummonerSpells", SetSummonerSpellsCallback)
MyWindow.AddCallBackToScript("getRecentPlayers", GetRecentPlayersCallback)
MyWindow.AddCallBackToScript("Close", CloseWindow)
MyWindow.AddCallBackToScript("DragWindow", DragWindow)
MyWindow.AddCallBackToScript("Minimize", MinimizeWindow)
MyWindow.AddCallBackToScript("Maximize", MaximizeWindow)

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
global lastGameflow := "INIT"
global wasLcuConnected := false

loop {
    historyTimer++
    
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
        LogToWeb("LCU connection established. Syncing active configuration and inventory...", "success")
    } else if (!lcuConnected && wasLcuConnected) {
        wasLcuConnected := false
        championsLoaded := false
        LogToWeb("LCU connection lost. Standing by...", "warning")
    }
    
    if (lcuConnected) {
        ; 1. Fast checks (every 1 second)
        try {
            tempMe := APICall("GET", "/lol-summoner/v1/current-summoner")
            if (IsObject(tempMe) && (tempMe.Has("gameName") || tempMe.Has("displayName"))) {
                gameName := tempMe.Has("gameName") ? tempMe["gameName"] : tempMe["displayName"]
                tagLine := tempMe.Has("tagLine") ? tempMe["tagLine"] : ""
                summonerLevel := tempMe.Has("summonerLevel") ? tempMe["summonerLevel"] : 0
                iconId := tempMe.Has("profileIconId") ? tempMe["profileIconId"] : 29
                puuid := tempMe.Has("puuid") ? tempMe["puuid"] : ""
                summonerId := tempMe.Has("summonerId") ? tempMe["summonerId"] : 0
                
                sessionSecs := (A_TickCount - sessionStartTime) // 1000
                sessionTime := FormatSessionTime(sessionSecs)
                
                global me := Map("lol", Map(
                    "gameName", gameName,
                    "tagLine", tagLine,
                    "summonerLevel", summonerLevel,
                    "iconId", iconId,
                    "puuid", puuid,
                    "summonerId", summonerId,
                    "friendsCount", friendsCount,
                    "friendsOnline", friendsOnline,
                    "recentWinRate", recentWinRate,
                    "sessionTime", sessionTime
                ))
            } else {
                global me := Map()
            }
        } catch {
            global me := Map()
        }
        
        try {
            tempFriends := APICall("GET", "/lol-chat/v1/friends")
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
        
        try {
            tempGameflow := APICall("GET", "/lol-gameflow/v1/gameflow-phase")
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
                tempHistory := APICall("GET", "/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=0&endIndex=49")
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
            LogToWeb("App dashboard UI initialized.", "info")
            if (gameflow != "") {
                LogToWeb("LCU connected. Current phase: " gameflow, "success")
            } else {
                LogToWeb("LCU disconnected. Waiting for League client to start...", "warning")
            }
        }
        
        if (lcuConnected && !championsLoaded && IsObject(me) && me.Has("lol") && me["lol"].Has("summonerId") && me["lol"]["summonerId"] > 0) {
            champTimer++
            if (champTimer >= 10) {
                champTimer := 0
                summonerId := me["lol"]["summonerId"]
                champs := APICall("GET", "/lol-champions/v1/inventories/" summonerId "/champions-minimal")
                if (Type(champs) == "Array" && champs.Length > 0) {
                    global championMap := Map()
                    for c in champs {
                        if (c.Has("id")) {
                            championMap[c["id"]] := c
                        }
                    }
                    LogToWeb("Successfully loaded " champs.Length " champions into AHK cache.", "success")
                    MyWindow.ExecuteScriptAsync("loadChampsFromLCU(" JSON.Dump(champs) ")")
                    championsLoaded := true
                }
            }
        }
        
        MyWindow.ExecuteScriptAsync("updateDashboard(" JSON.Dump(me) ", '" gameflow "', " JSON.Dump(match_history_dic) ", " reportQueue.Length ", '" reportStatus "')")
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
}

CloseWindow(WebView) {
    ExitApp()
}

DragWindow(WebView) {
    DllCall("ReleaseCapture")
    try {
        PostMessage(0x0112, 0xF012, 0,, "ahk_id " WebView.Gui.Hwnd)
    } catch {
        PostMessage(0x0112, 0xF012, 0,, "ahk_id " MyWindow.Hwnd)
    }
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
    global config
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

SaveConfig() {
    try {
        fileObj := FileOpen("config.json", "w", "UTF-8")
        fileObj.Write(JSON.Dump(config, True))
        fileObj.Close()
    } catch Error as e {
        LogToWeb("Failed to save config.json to disk: " e.Message, "error")
    }
}

WebTooltipEvent(WebView, Msg) {
    ToolTip(Msg)
    SetTimer((*) => ToolTip(), -1500)
}

DodgeLobbyCallback(WebView) {
    LogToWeb("Dodge Lobby: Initiating dodge process...", "warning")
    
    ; 1. Try custom game quit first
    res := APICall("POST", "/lol-lobby-team-builder/champ-select/v1/session/quit", "{}")
    
    ; 2. If it's a matchmaking queue (or the quit call fails/has error), trigger a full client quit via process-control
    if (IsObject(res) && res.Has("error")) {
        LogToWeb("Dodge Lobby: Custom quit returned error (likely a PvP lobby). Requesting client closure to dodge...", "warning")
        resQuit := APICall("POST", "/process-control/v1/process/quit", "{}")
        if (IsObject(resQuit) && resQuit.Has("error")) {
            ; Fallback: OS process close in case LCU process control fails
            LogToWeb("Dodge Lobby: LCU quit failed. Terminating LeagueClient.exe processes via OS...", "error")
            try {
                ProcessClose("LeagueClient.exe")
                ProcessClose("LeagueClientUx.exe")
                LogToWeb("Dodge Lobby: Terminated League client processes via OS.", "success")
            } catch Error as e {
                LogToWeb("Dodge Lobby: OS process close failed: " e.Message, "error")
            }
        } else {
            LogToWeb("Dodge Lobby: Client closure initiated successfully to trigger dodge.", "success")
        }
    } else {
        LogToWeb("Dodge Lobby: Sent custom game lobby quit successfully!", "success")
    }
}

TriggerMassDisenchantCallback(WebView) {
    LogToWeb("Mass Disenchant: Manual trigger initiated by user...", "info")
    RunMassDisenchant(false)
}

BenchSwapCallback(WebView, champId) {
    global bypassAutoPick
    champName := GetChampionName(champId)
    LogToWeb("Manual Swap: User requested swap to " champName " (ID:" champId ")", "warning")
    res := APICall("POST", "/lol-champ-select/v1/session/bench/swap/" champId)
    if (IsObject(res) && res.Has("error")) {
        errStatus := res.Has("status") ? res["status"] : "?"
        errMsg := res.Has("error") ? res["error"] : "Unknown"
        LogToWeb("Manual Swap: FAILED for " champName " — HTTP " errStatus " (" errMsg ")", "error")
    } else {
        LogToWeb("Manual Swap: Swapped to " champName " successfully! Auto-picker paused for this lobby.", "success")
        bypassAutoPick := true
    }
}

SetSummonerSpellsCallback(WebView, spell1Id, spell2Id) {
    LogToWeb("Summoner Spells: Swapping spells to spell1=" spell1Id ", spell2=" spell2Id "...", "info")
    body := '{"spell1Id":' spell1Id ',"spell2Id":' spell2Id '}'
    res := APICall("PATCH", "/lol-champ-select/v1/session/my-selection", body)
    if (IsObject(res) && res.Has("error")) {
        errStatus := res.Has("status") ? res["status"] : "?"
        errMsg := res.Has("error") ? res["error"] : "Unknown"
        LogToWeb("Summoner Spells: Failed to change spells. HTTP " errStatus " (" errMsg ")", "error")
    } else {
        LogToWeb("Summoner Spells: Spells updated successfully!", "success")
    }
}

LogToWeb(msg, type := "info") {
    global MyWindow, initConfigSent
    
    if (IsSet(MyWindow) && initConfigSent) {
        try {
            cleanMsg := StrReplace(msg, "\", "\\")
            cleanMsg := StrReplace(cleanMsg, "'", "\'")
            cleanMsg := StrReplace(cleanMsg, "`n", " ")
            cleanMsg := StrReplace(cleanMsg, "`r", "")
            MyWindow.ExecuteScriptAsync("logSystemMessage('" cleanMsg "', '" type "')")
        } catch {
            ; Ignore frontend log call failures
        }
    }
}

GetChampionName(id) {
    global championMap
    if (IsSet(championMap) && championMap.Has(id)) {
        val := championMap[id]
        if (IsObject(val) && val.Has("name"))
            return val["name"]
        return val
    }
    return "ID " id
}

SaveHistory() {
    global match_history_dic
    try {
        fileObj := FileOpen("history.json", "w", "UTF-8")
        fileObj.Write(JSON.Dump(match_history_dic, True))
        fileObj.Close()
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
    global match_history_dic
    match_history_dic[gameId] := value
    SaveHistory()
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