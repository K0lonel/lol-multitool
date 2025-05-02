#Requires AutoHotkey v2.0+
#SingleInstance Force

#Include <utilities>
#Include <JSON>
#Include <API>
#Include <plugins>
#Include <WebViewToo/AHK Resources/WebViewToo>

if(!FileExist("history.json"))
    FileAppend("{}", "history.json")
global match_history_dic := JSON.Load(FileRead("history.json"))

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

global MyWindow := WebViewToo(,,, True)
MyWindow.OnEvent("Close", (*) => ExitSave())
MyWindow.Load("lib/WebViewToo/Pages/index.html")
MyWindow.Show("w1200 h800 Center", "LoL-App")


for plugin in plugins
    SetTimer(plugin, 1000)
; msgbox plugin.name

loop {
    global me := APICall("GET", "/lol-chat/v1/me")
    global friends := APICall("GET", "/lol-chat/v1/friends")
    global gameflow := APICall("GET", "/lol-gameflow/v1/gameflow-phase")
    global match_history := APICall("GET", "/lol-match-history/v1/products/lol/current-summoner/matches")
    
    MyWindow.ExecuteScript("document.querySelector('#client_state').innerText = 'Client State: " gameflow "'")
    sleep 1000
}
return

$^t::ExitApp
^r::Reload

ExitSave(){
    FileDelete("history.json")
    FileAppend(JSON.Dump(match_history_dic, True), "history.json")
    ExitApp()
}