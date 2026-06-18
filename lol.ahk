#Requires AutoHotkey v2.0+
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

if (FileExist("debug.log")) {
    try FileDelete("debug.log")
}

#Include <utilities>
#Include <JSON>
#Include <API>
#Include <plugins>
#Include <WebViewToo/AHK Resources/WebViewToo>
FileEncoding "UTF-8"
JSON.EscapeUnicode := False

if(!FileExist("historyView.json"))
    FileAppend("{}", "historyView.json")
global match_history_dic := JSON.Load(FileRead("historyView.json"))
global friend_puuid := Array()
global reportList := ""
global reportQueue := Array()
global reportStatus := "Idle"
global championsLoaded := false
global championMap := Map()
global checkedGames := Array()

; Load or create configuration
if(!FileExist("config.json")) {
    defaultConfig := Map(
        "autoAccept", True,
        "autoReport", True,
        "acceptDelay", 0,
        "reportCategories", ["NEGATIVE_ATTITUDE", "VERBAL_ABUSE", "HATE_SPEECH", "THIRD_PARTY_TOOLS"],
        "autoPickBenchEnabled", False,
        "autoPickBenchIds", Array(),
        "favoriteChampIds", Array()
    )
    FileAppend(JSON.Dump(defaultConfig, True), "config.json")
}
global config := JSON.Load(FileRead("config.json"))
if (!config.Has("favoriteChampIds")) {
    config["favoriteChampIds"] := Array()
    SaveConfig()
}

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

global MyWindow := WebViewToo(,,, True)
MyWindow.OnEvent("Close", (*) => ExitSave())

; Register callbacks
MyWindow.AddCallBackToScript("updateConfig", UpdateConfigCallback)
MyWindow.AddCallBackToScript("Tooltip", WebTooltipEvent)
MyWindow.AddCallBackToScript("dodgeLobby", DodgeLobbyCallback)

MyWindow.Load("lib/WebViewToo/Pages/index.html")
MyWindow.Show("w1200 h800 Center", "LoL-App")

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
                
                global me := Map("lol", Map(
                    "gameName", gameName,
                    "tagLine", tagLine,
                    "summonerLevel", summonerLevel,
                    "iconId", iconId,
                    "puuid", puuid
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
                if (friends.Length != friend_puuid.Length) {
                    friend_puuid := Array()
                    for index, friend in friends
                        friend_puuid.Push(friend["puuid"])
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
                tempHistory := APICall("GET", "/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=0&endIndex=3")
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
            MyWindow.ExecuteScript("initConfig(" JSON.Dump(config) ")")
            initConfigSent := true
            LogToWeb("App dashboard UI initialized.", "info")
            if (gameflow != "") {
                LogToWeb("LCU connected. Current phase: " gameflow, "success")
            } else {
                LogToWeb("LCU disconnected. Waiting for League client to start...", "warning")
            }
        }
        
        if (lcuConnected && !championsLoaded && IsObject(me) && me.Has("lol")) {
            champTimer++
            if (champTimer >= 10) {
                champTimer := 0
                champs := APICall("GET", "/lol-champions/v1/champions")
                if (Type(champs) == "Array" && champs.Length > 0) {
                    global championMap := Map()
                    for c in champs {
                        if (c.Has("id") && c.Has("name")) {
                            championMap[c["id"]] := c["name"]
                        }
                    }
                    LogToWeb("Successfully loaded " champs.Length " champions into AHK cache.", "success")
                    MyWindow.ExecuteScript("loadChampsFromLCU(" JSON.Dump(champs) ")")
                    championsLoaded := true
                }
            }
        }
        
        MyWindow.ExecuteScript("updateDashboard(" JSON.Dump(me) ", '" gameflow "', " JSON.Dump(match_history_dic) ", " reportQueue.Length ", '" reportStatus "')")
    } catch Error as e {
        LogToWeb("Error in main loop script execution: " e.Message, "error")
    }
    
    sleep 1000
}
return

$^t::ExitApp
^r::Reload

ExitSave(){
    SaveHistory()
    ExitApp()
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
    try APICall("POST", "/lol-login/v1/shutdown-and-disable")
}

LogToWeb(msg, type := "info") {
    global MyWindow, initConfigSent
    
    if (IsSet(MyWindow) && initConfigSent) {
        try {
            cleanMsg := StrReplace(msg, "\", "\\")
            cleanMsg := StrReplace(cleanMsg, "'", "\'")
            cleanMsg := StrReplace(cleanMsg, "`n", " ")
            cleanMsg := StrReplace(cleanMsg, "`r", "")
            MyWindow.ExecuteScript("logSystemMessage('" cleanMsg "', '" type "')")
        } catch {
            ; Ignore frontend log call failures
        }
    }
}

GetChampionName(id) {
    global championMap
    if (IsSet(championMap) && championMap.Has(id))
        return championMap[id]
    return "ID " id
}

SaveHistory() {
    global match_history_dic
    try {
        fileObj := FileOpen("historyView.json", "w", "UTF-8")
        fileObj.Write(JSON.Dump(match_history_dic, True))
        fileObj.Close()
        LogToWeb("Successfully saved match history to disk.", "debug")
    } catch Error as e {
        LogToWeb("Failed to save historyView.json to disk: " e.Message, "error")
    }
}

HasHistoryGame(gameId) {
    global match_history_dic
    return match_history_dic.Has(String(gameId)) || match_history_dic.Has(Integer(gameId))
}

GetHistoryGame(gameId) {
    global match_history_dic
    if (match_history_dic.Has(String(gameId)))
        return match_history_dic[String(gameId)]
    if (match_history_dic.Has(Integer(gameId)))
        return match_history_dic[Integer(gameId)]
    return ""
}

SetHistoryGame(gameId, value) {
    global match_history_dic
    if (match_history_dic.Has(Integer(gameId))) {
        match_history_dic[Integer(gameId)] := value
    } else {
        match_history_dic[String(gameId)] := value
    }
}