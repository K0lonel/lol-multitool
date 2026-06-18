#Requires AutoHotkey v2.0+
#SingleInstance Force

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

; Load or create configuration
if(!FileExist("config.json")) {
    defaultConfig := Map(
        "autoAccept", True,
        "autoReport", True,
        "autoTFT", False,
        "acceptDelay", 0,
        "tftSurrenderTime", 600,
        "reportCategories", ["NEGATIVE_ATTITUDE", "VERBAL_ABUSE", "HATE_SPEECH", "THIRD_PARTY_TOOLS"]
    )
    FileAppend(JSON.Dump(defaultConfig, True), "config.json")
}
global config := JSON.Load(FileRead("config.json"))

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

global MyWindow := WebViewToo(,,, True)
MyWindow.OnEvent("Close", (*) => ExitSave())

; Register callbacks
MyWindow.AddCallBackToScript("updateConfig", UpdateConfigCallback)
MyWindow.AddCallBackToScript("Tooltip", WebTooltipEvent)

MyWindow.Load("lib/WebViewToo/Pages/index.html")
MyWindow.Show("w1200 h800 Center", "LoL-App")

for plugin in plugins
    SetTimer(plugin, 1000)

global initConfigSent := false

loop {
    global me := APICall("GET", "/lol-chat/v1/me")
    global friends := APICall("GET", "/lol-chat/v1/friends")
    global gameflow := APICall("GET", "/lol-gameflow/v1/gameflow-phase")
    global match_history := APICall("GET", "/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=0&endIndex=49")
    
    try if(friends.Length != friend_puuid.Length) {
        friend_puuid := Array()
        for index, friend in friends
            friend_puuid.Push(friend["puuid"])
    }
    
    try {
        if (!initConfigSent) {
            MyWindow.ExecuteScript("initConfig(" JSON.Dump(config) ")")
            initConfigSent := true
        }
        MyWindow.ExecuteScript("updateDashboard(" JSON.Dump(me) ", '" gameflow "', " JSON.Dump(match_history_dic) ")")
    }
    
    sleep 1000
}
return

$^t::ExitApp
^r::Reload

ExitSave(){
    FileExist("historyView.json") && FileDelete("historyView.json")
    FileAppend(JSON.Dump(match_history_dic, True), "historyView.json")
    ExitApp()
}

UpdateConfigCallback(WebView, key, value) {
    global config
    if (key == "reportCategories") {
        config["reportCategories"] := JSON.Load(value)
    } else if (key == "acceptDelay" || key == "tftSurrenderTime") {
        config[key] := Number(value)
    } else if (value == "true" || value = True) {
        config[key] := True
    } else if (value == "false" || value = False) {
        config[key] := False
    } else {
        config[key] := value
    }
    SaveConfig()
}

SaveConfig() {
    FileExist("config.json") && FileDelete("config.json")
    FileAppend(JSON.Dump(config, True), "config.json")
}

WebTooltipEvent(WebView, Msg) {
    ToolTip(Msg)
    SetTimer((*) => ToolTip(), -1500)
}