#Requires AutoHotkey v2.0+
#SingleInstance Force
SetWorkingDir(A_ScriptDir)


#Include <utilities>
#Include <JSON>
#Include <API>
#Include <plugins>
#Include <WebView2/WebViewToo>
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
        "foldReport", False
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

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

global MyWindow := WebViewGui("-Caption +Resize", "LoL-App")
MyWindow.OnEvent("Close", (*) => ExitApp())
OnExit(ExitSave)

; Register callbacks
MyWindow.AddCallBackToScript("updateConfig", UpdateConfigCallback)
MyWindow.AddCallBackToScript("Tooltip", WebTooltipEvent)
MyWindow.AddCallBackToScript("dodgeLobby", DodgeLobbyCallback)
MyWindow.AddCallBackToScript("benchSwap", BenchSwapCallback)
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
global historyTimer := 9
global champTimer := 9
global lastGameflow := "INIT"

loop {
    historyTimer++
    
    ; Determine connection status in a fast and CPU-efficient way
    lcuConnected := false
    if (LCU.Token != "" || LCU.Initialize()) {
        lcuConnected := true
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
                
                global me := Map("lol", Map(
                    "gameName", gameName,
                    "tagLine", tagLine,
                    "summonerLevel", summonerLevel,
                    "iconId", iconId,
                    "puuid", puuid,
                    "summonerId", summonerId
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
    
    ; 2. Match History (every 30 seconds)
    if (historyTimer >= 30) {
        historyTimer := 0
        if (lcuConnected) {
            try {
                tempHistory := APICall("GET", "/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=0&endIndex=49")
                if (IsObject(tempHistory) && tempHistory.Has("games")) {
                    global match_history := tempHistory
                    ; Removed LCU match history update log to prevent console spam
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
$^t::ExitApp
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
    ; SaveHistory()
}

CloseWindow(WebView) {
    ExitApp()
}

DragWindow(WebView) {
    PostMessage(0x00A1, 2,, "ahk_id " WebView.Hwnd)
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
    if (key == "reportCategories" || key == "autoPickBenchIds" || key == "favoriteChampIds") {
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
    LogToWeb("Dodge Lobby: User requested dodge", "warning")
    res := APICall("POST", "/lol-lobby-team-builder/champ-select/v1/session/quit")
    if (IsObject(res) && res.Has("error")) {
        errStatus := res.Has("status") ? res["status"] : "?"
        errMsg := res.Has("error") ? res["error"] : "Unknown"
        LogToWeb("Dodge Lobby: FAILED — HTTP " errStatus " (" errMsg ")", "error")
    } else {
        LogToWeb("Dodge Lobby: Sent dodge request successfully!", "success")
    }
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