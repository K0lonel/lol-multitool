#Requires AutoHotkey v2.0
#SingleInstance Force

; ordered includes
#Include <utilities>
#Include <JSON>
; #Include <LCU>
#Include <API>
#Include <plugins>
; #Include WebViewToo/AHK Resources/WebView2.ahk
#Include <WebViewToo/AHK Resources/WebViewToo>

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

global MyWindow := WebViewToo(,,, True)
MyWindow.OnEvent("Close", (*) => ExitApp())
MyWindow.Load("lib/WebViewToo/Pages/index.html")
MyWindow.Show("w1200 h800 Center", "LoL-App")

SetTimer(autoTFT, 1000)
return

$^x::ExitApp
$^r::Reload