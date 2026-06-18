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

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

global MyWindow := WebViewToo(,,, True)
MyWindow.OnEvent("Close", (*) => ExitSave())
MyWindow.Load("lib/WebViewToo/Pages/index.html")
MyWindow.Show("w1200 h800 Center", "LoL-App")

for plugin in plugins
    SetTimer(plugin, 1000)
; msgbox plugin.name
MyWindow.ExecuteScript("const viewer = new JSONViewer()")
MyWindow.ExecuteScript("document.querySelector('#jsonBox').appendChild(viewer.getContainer())")

loop {
    global me := APICall("GET", "/lol-chat/v1/me")
    global friends := APICall("GET", "/lol-chat/v1/friends")
    global gameflow := APICall("GET", "/lol-gameflow/v1/gameflow-phase")
    global match_history := APICall("GET", "/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=0&endIndex=49") ;"?begIndex=0&endIndex=50"
    ; OutputDebug(gameflow)
    try if(friends.Length != friend_puuid.Length) {
        friend_puuid := Array()
        for index, friend in friends
            friend_puuid.Push(friend["puuid"])
    }
    MyWindow.ExecuteScript("document.querySelector('#client_state').innerText = 'Client State: " gameflow "'")
    MyWindow.ExecuteScript("document.querySelector('#jsonBox').textContent = JSON.stringify(" reportList ", null, 2)")
    
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