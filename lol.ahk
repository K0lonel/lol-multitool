#Requires AutoHotkey v2.0+
#SingleInstance Force

#Include <utilities>
#Include <JSON>
#Include <API>
#Include <plugins>
#Include <WebViewToo/AHK Resources/WebViewToo>

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

global MyWindow := WebViewToo(,,, True)
MyWindow.OnEvent("Close", (*) => ExitApp())
MyWindow.Load("lib/WebViewToo/Pages/index.html")
MyWindow.Show("w1200 h800 Center", "LoL-App")


for plugin in plugins
    SetTimer(plugin, 1000)
; msgbox plugin.name

loop {
    sleep 1000
    global me := APICall("GET", "/lol-chat/v1/me")
    global friends := APICall("GET", "/lol-chat/v1/friends")
    global gameflow := APICall("GET", "/lol-gameflow/v1/gameflow-phase")
    MyWindow.ExecuteScript("document.querySelector('#client_state').innerText = 'Client State: " gameflow "'")
}
return

$^t::ExitApp
^r::Reload