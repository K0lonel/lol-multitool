#Requires AutoHotkey v2.0
#Include ../lib/utilities.ahk
#Include ../lib/LCU.ahk
#Include ../lib/API.ahk

global me := APICall("GET", "/lol-chat/v1/me")
global friends := APICall("GET", "/lol-chat/v1/friends")
global gameflow := APICall("GET", "/lol-gameflow/v1/gameflow-phase")