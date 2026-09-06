#Requires AutoHotkey v2.0
#Include ../lol.ahk

global activeEmoteCancelKey := ""
global activeEmoteCancelSlot := 0
global registeredHoldKey := ""
global registeredTriggerKey := ""
plugins.Push(emoteCancelMonitor)

; ==============================================================================
; WebView2 Always-On-Top Layered Wheel Overlay
; ==============================================================================
class EmoteWheelOverlay {
    static guiWnd := 0
    static width := 340
    static height := 340
    static isShowing := false
    static currentHoverSlot := 0
    
    static Init() {
        global MyWindow
        if (this.guiWnd)
            return
            
        settings := {DefaultWidth: this.width, DefaultHeight: this.height}
        if (IsSet(MyWindow) && MyWindow && MyWindow.HasProp("Environment") && MyWindow.Environment) {
            settings.CreatedEnvironment := MyWindow.Environment
        }
        
        try EnvSet("WEBVIEW2_DEFAULT_BACKGROUND_COLOR", "0")
            
        ; Create WebViewGui: AlwaysOnTop, frameless, no taskbar, click-through, no activation, no redirection bitmap
        this.guiWnd := WebViewGui("-Caption +AlwaysOnTop +ToolWindow +Owner +E0x00200000 +E0x20 +E0x08000000", "EmoteWheelOverlay", , settings)
        
        ; Destroy and neutralize Sizers helper window created by WebViewToo (which draws a 6px resizing border)
        if (this.guiWnd.HasProp("Sizers") && this.guiWnd.Sizers) {
            try this.guiWnd.Sizers.Destroy()
            this.guiWnd.Sizers := {
                Destroy: (*) => 0,
                Move: (*) => 0,
                Show: (*) => 0,
                Hide: (*) => 0
            }
        }
        
        ; Suppress Windows 11 DWM border and rounded corner frame
        pvBorder := 0xFFFFFFFE, pvCorner := 1
        DllCall("Dwmapi.dll\DwmSetWindowAttribute", "Ptr", this.guiWnd.Hwnd, "UInt", 34, "UInt*", pvBorder, "UInt", 4) ; DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE
        DllCall("Dwmapi.dll\DwmSetWindowAttribute", "Ptr", this.guiWnd.Hwnd, "UInt", 33, "UInt*", pvCorner, "UInt", 4) ; DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_DONOTROUND
        
        ; Strip any residual frame or border window styles
        WinSetStyle("-0x00C40000", this.guiWnd.Hwnd) ; -WS_BORDER -WS_THICKFRAME -WS_CAPTION
        WinSetExStyle("-0x00000300", this.guiWnd.Hwnd) ; -WS_EX_WINDOWEDGE -WS_EX_CLIENTEDGE
        
        ; Set WebView2 controller background to 0 (fully transparent)
        try {
            this.guiWnd.Control.wvc.DefaultBackgroundColor := 0
        }
        
        ; Shape top-level window into an exact circle matching the wheel
        this.ApplyCircularRegion()
        
        pagesDir := A_ScriptDir . "\Pages"
        this.guiWnd.BrowseFolder(pagesDir)
        this.guiWnd.Navigate("emoteWheel.html")
    }
    
    static ApplyCircularRegion() {
        if (!this.guiWnd)
            return
        w := this.width, h := this.height
        ; Apply elliptic region only to top-level window (bounds 3 to w-3)
        ; Do NOT clip child windows or Chromium D3D swapchains, which causes visible border outlines
        hrgnWnd := DllCall("gdi32\CreateEllipticRgn", "Int", 3, "Int", 3, "Int", w - 3, "Int", h - 3, "Ptr")
        DllCall("user32\SetWindowRgn", "Ptr", this.guiWnd.Hwnd, "Ptr", hrgnWnd, "Int", 1)
    }
    
    static ShowAt(screenX, screenY, hoverSlot := 0, activeSlot := 1, keyNames := "") {
        this.Init()
        
        w := this.width, h := this.height
        posX := screenX - (w // 2)
        posY := screenY - (h // 2)
        
        this.guiWnd.Move(posX, posY)
        this.ApplyCircularRegion()
        this.guiWnd.Show("NA")
        this.isShowing := true
        this.currentHoverSlot := hoverSlot
        
        this.UpdateState(hoverSlot, activeSlot, keyNames)
    }
    
    static UpdateState(hoverSlot, activeSlot, keyNames) {
        if (!this.guiWnd)
            return
        if (!IsObject(keyNames) || keyNames.Length < 5)
            keyNames := ["Num 1", "Num 2", "Num 3", "Num 4", "Num 5"]
            
        keysJson := '["' . keyNames[1] . '","' . keyNames[2] . '","' . keyNames[3] . '","' . keyNames[4] . '","' . keyNames[5] . '"]'
        this.guiWnd.ExecuteScriptAsync("if (typeof updateWheelState === 'function') updateWheelState(" . hoverSlot . ", " . activeSlot . ", " . keysJson . ");")
    }
    
    static SetHoverSlot(hoverSlot) {
        if (!this.guiWnd || !this.isShowing)
            return
        if (this.currentHoverSlot == hoverSlot)
            return
        this.currentHoverSlot := hoverSlot
        this.guiWnd.ExecuteScriptAsync("if (typeof setHoverSlot === 'function') setHoverSlot(" . hoverSlot . ");")
    }
    
    static UpdateHover(hoverSlot) {
        this.SetHoverSlot(hoverSlot)
    }
    
    static Hide() {
        if (this.isShowing && this.guiWnd) {
            this.guiWnd.Hide()
            this.isShowing := false
        }
    }
    
    static Shutdown() {
        if (this.guiWnd) {
            try {
                this.guiWnd.Destroy()
            }
            this.guiWnd := 0
        }
    }
}

; ==============================================================================
; Plugin Core & Monitor
; ==============================================================================
emoteCancelMonitor() {
    global gameflow, activeEmoteCancelKey, activeEmoteCancelSlot, config
    ; Stop active loop if emote cancel is disabled
    if (config.Has("emoteCancelEnabled") && !config["emoteCancelEnabled"] && activeEmoteCancelKey != "") {
        activeEmoteCancelKey := ""
        activeEmoteCancelSlot := 0
        LogToWeb("Emote Cancel: Loop stopped (disabled in settings).", "info", "emoteCancelSilent")
        UpdateEmoteCancelUI()
        return
    }
    ; Stop active loop if gameflow transitions away from InProgress and League is not running
    if (gameflow != "InProgress" && !WinExist("ahk_exe League of Legends.exe") && activeEmoteCancelKey != "") {
        activeEmoteCancelKey := ""
        activeEmoteCancelSlot := 0
        LogToWeb("Emote Cancel: Loop stopped (gameflow no longer InProgress).", "info", "emoteCancelSilent")
        UpdateEmoteCancelUI()
    }
}

CanEmoteCancel(ThisHotkey := "") {
    global gameflow, config
    if (config.Has("emoteCancelEnabled") && !config["emoteCancelEnabled"])
        return false
    if (WinActive("ahk_exe League of Legends.exe"))
        return true
    if (WinExist("ahk_exe League of Legends.exe"))
        return false
    return (gameflow == "InProgress")
}

GetEmoteKeyLabels() {
    global config
    labels := Array()
    for i in [1, 2, 3, 4, 5] {
        rawKey := (config.Has("emoteCancelTarget" . i) && config["emoteCancelTarget" . i] != "") ? config["emoteCancelTarget" . i] : ("Numpad" . i)
        if (SubStr(rawKey, 1, 6) = "Numpad")
            labels.Push("Num " . SubStr(rawKey, 7))
        else
            labels.Push(rawKey)
    }
    return labels
}

SelectEmoteCancelSlot(slot) {
    global config, MyWindow, activeEmoteCancelKey, activeEmoteCancelSlot
    slot := Integer(slot)
    if (slot < 1 || slot > 5)
        slot := 1
    
    ; If currently looping a different slot, stop the loop cleanly
    if (activeEmoteCancelKey != "" && activeEmoteCancelSlot != slot) {
        activeEmoteCancelKey := ""
        activeEmoteCancelSlot := 0
        UpdateEmoteCancelUI()
    }
    
    ; Avoid redundant disk save, log spam, and JS update if slot hasn't changed
    alreadyActive := (config.Has("emoteCancelActiveSlot") && config["emoteCancelActiveSlot"] == slot)
    if (alreadyActive && (activeEmoteCancelKey == "" || activeEmoteCancelSlot == slot))
        return
    
    config["emoteCancelActiveSlot"] := slot
    SaveConfig()
    
    targetKey := (config.Has("emoteCancelTarget" . slot) && config["emoteCancelTarget" . slot] != "") ? config["emoteCancelTarget" . slot] : ("Numpad" . slot)
    LogToWeb("Emote Cancel: Armed slot " slot " (Emote " slot " -> " targetKey ")", "info", "emoteCancelSilent")
    
    if (IsSet(MyWindow)) {
        try {
            MyWindow.ExecuteScriptAsync("if (typeof onActiveEmoteSlotChanged === 'function') onActiveEmoteSlotChanged(" slot ");")
        }
    }
}

; ==============================================================================
; Hotkey Event Handlers
; ==============================================================================
OnEmoteWheelKeyDown(ThisHotkey := "") {
    global config
    if (!CanEmoteCancel(ThisHotkey))
        return
    
    holdKey := (config.Has("emoteCancelHoldKey") && config["emoteCancelHoldKey"] != "") ? config["emoteCancelHoldKey"] : "XButton1"
    activeSlot := (config.Has("emoteCancelActiveSlot") && config["emoteCancelActiveSlot"] >= 1 && config["emoteCancelActiveSlot"] <= 5) ? config["emoteCancelActiveSlot"] : 1
    
    CoordMode("Mouse", "Screen")
    MouseGetPos(&cx, &cy)
    
    keyLabels := GetEmoteKeyLabels()
    currentHoverSlot := activeSlot
    
    EmoteWheelOverlay.ShowAt(cx, cy, currentHoverSlot, activeSlot, keyLabels)
    
    while GetKeyState(holdKey, "P") {
        if (WinExist("ahk_exe League of Legends.exe") && !WinActive("ahk_exe League of Legends.exe"))
            break
        if (config.Has("emoteCancelEnabled") && !config["emoteCancelEnabled"])
            break
            
        MouseGetPos(&mx, &my)
        dx := mx - cx
        dy := my - cy
        dist := Sqrt(dx*dx + dy*dy)
        
        if (dist < 46) {
            hoverSlot := 5
        } else {
            angle := DllCall("msvcrt\atan2", "Double", dy, "Double", dx, "Cdecl Double") * (180.0 / 3.141592653589793)
            if (angle >= -135.0 && angle < -45.0)
                hoverSlot := 1
            else if (angle >= -45.0 && angle < 45.0)
                hoverSlot := 2
            else if (angle >= 45.0 && angle < 135.0)
                hoverSlot := 3
            else
                hoverSlot := 4
        }
        
        if (hoverSlot != currentHoverSlot) {
            currentHoverSlot := hoverSlot
            EmoteWheelOverlay.SetHoverSlot(currentHoverSlot)
        }
        Sleep(16)
    }
    
    EmoteWheelOverlay.Hide()
    
    if (currentHoverSlot >= 1 && currentHoverSlot <= 5) {
        SelectEmoteCancelSlot(currentHoverSlot)
    }
}

OnEmoteLoopTrigger(ThisHotkey := "") {
    global config
    if (!CanEmoteCancel(ThisHotkey))
        return
    slot := (config.Has("emoteCancelActiveSlot") && config["emoteCancelActiveSlot"] >= 1 && config["emoteCancelActiveSlot"] <= 5) ? config["emoteCancelActiveSlot"] : 1
    targetKey := (config.Has("emoteCancelTarget" . slot) && config["emoteCancelTarget" . slot] != "") ? config["emoteCancelTarget" . slot] : ("Numpad" . slot)
    emoteCancel(targetKey, slot)
}

emoteCancel(key, slot := 0) {
    global activeEmoteCancelKey, activeEmoteCancelSlot, config, gameflow
    if (key == "")
        return
    
    ; If the key is already running, toggle OFF
    if (activeEmoteCancelKey == key) {
        activeEmoteCancelKey := ""
        activeEmoteCancelSlot := 0
        slotName := (slot > 0) ? ("Emote " . slot) : key
        LogToWeb("Emote Cancel: Toggled OFF for " slotName " (" key ")", "info", "emoteCancelSilent")
        UpdateEmoteCancelUI()
        return
    }
    
    activeEmoteCancelKey := key
    activeEmoteCancelSlot := slot
    slotName := (slot > 0) ? ("Emote " . slot) : key
    LogToWeb("Emote Cancel: Toggled ON for " slotName " (" key " loop)", "success", "emoteCancelSilent")
    UpdateEmoteCancelUI()
    
    cleanKey := (SubStr(key, 1, 1) == "{") ? key : "{" key "}"
    
    while (activeEmoteCancelKey == key && (!config.Has("emoteCancelEnabled") || config["emoteCancelEnabled"]) && (gameflow == "InProgress" || WinActive("ahk_exe League of Legends.exe"))) {
        ; Stop if League window loses focus
        if (WinExist("ahk_exe League of Legends.exe") && !WinActive("ahk_exe League of Legends.exe")) {
            activeEmoteCancelKey := ""
            activeEmoteCancelSlot := 0
            LogToWeb("Emote Cancel: Stopped (League lost focus)", "warning", "emoteCancelSilent")
            UpdateEmoteCancelUI()
            break
        }
        
        delay := (config.Has("emoteCancelDelay") && IsNumber(config["emoteCancelDelay"])) ? Integer(config["emoteCancelDelay"]) : 50
        if (delay < 10)
            delay := 10
        
        ; 1. Press rightclick (if enabled)
        if (!config.Has("emoteCancelRightClick") || config["emoteCancelRightClick"]) {
            Click("Right")
        }
        
        ; 3. Sleep configurable (default 50)
        Sleep(delay)

        ; 2. Press key specified in parameter
        Send(cleanKey)
    }
    
    if (activeEmoteCancelKey == key) {
        activeEmoteCancelKey := ""
        activeEmoteCancelSlot := 0
        if (config.Has("emoteCancelEnabled") && !config["emoteCancelEnabled"])
            LogToWeb("Emote Cancel: Stopped (disabled in settings)", "info", "emoteCancelSilent")
        UpdateEmoteCancelUI()
    }
}

UpdateEmoteCancelUI() {
    global MyWindow, activeEmoteCancelKey, activeEmoteCancelSlot
    if (IsSet(MyWindow)) {
        try {
            statusText := (activeEmoteCancelKey != "") ? activeEmoteCancelKey : "Idle"
            slotNum := (activeEmoteCancelSlot != "") ? activeEmoteCancelSlot : 0
            statusEscaped := StrReplace(StrReplace(statusText, "\", "\\"), "'", "\'")
            MyWindow.ExecuteScriptAsync("if (typeof updateEmoteCancelStatus === 'function') updateEmoteCancelStatus('" statusEscaped "', " slotNum ");")
        }
    }
}

RebindEmoteCancelHotkeys() {
    global registeredHoldKey, registeredTriggerKey, config, activeEmoteCancelKey, activeEmoteCancelSlot
    
    ; If disabled in config, immediately stop active loop and hide overlay
    if (config.Has("emoteCancelEnabled") && !config["emoteCancelEnabled"]) {
        if (activeEmoteCancelKey != "") {
            activeEmoteCancelKey := ""
            activeEmoteCancelSlot := 0
            LogToWeb("Emote Cancel: Loop stopped (disabled in settings).", "info", "emoteCancelSilent")
            UpdateEmoteCancelUI()
        }
        EmoteWheelOverlay.Hide()
    }
    
    holdKey := (config.Has("emoteCancelHoldKey") && config["emoteCancelHoldKey"] != "") ? config["emoteCancelHoldKey"] : "XButton1"
    triggerKey := (config.Has("emoteCancelTriggerKey") && config["emoteCancelTriggerKey"] != "") ? config["emoteCancelTriggerKey"] : "MButton"
    
    ; 1. Wheel Hold Key
    if (registeredHoldKey != holdKey) {
        if (registeredHoldKey != "") {
            try {
                HotIf(CanEmoteCancel)
                Hotkey("$*" . registeredHoldKey, "Off")
                HotIf()
            }
        }
        try {
            HotIf(CanEmoteCancel)
            Hotkey("$*" . holdKey, OnEmoteWheelKeyDown, "On")
            HotIf()
            registeredHoldKey := holdKey
        } catch Error as e {
            LogToWeb("Failed to bind wheel hold key " holdKey ": " e.Message, "error")
        }
    }
    
    ; 2. Loop Trigger Key
    if (registeredTriggerKey != triggerKey) {
        if (registeredTriggerKey != "") {
            try {
                HotIf(CanEmoteCancel)
                Hotkey("$*" . registeredTriggerKey, "Off")
                HotIf()
            }
        }
        try {
            HotIf(CanEmoteCancel)
            Hotkey("$*" . triggerKey, OnEmoteLoopTrigger, "On T2")
            HotIf()
            registeredTriggerKey := triggerKey
        } catch Error as e {
            LogToWeb("Failed to bind loop trigger key " triggerKey ": " e.Message, "error")
        }
    }
}

TriggerEmoteSlotCallback(WebView, slot) {
    global config
    if (!CanEmoteCancel()) {
        LogToWeb("Emote Cancel: Cannot trigger (League is not active or feature is disabled).", "warning", "emoteCancelSilent")
        return
    }
    slotInt := Integer(slot)
    targetKey := (config.Has("emoteCancelTarget" . slotInt) && config["emoteCancelTarget" . slotInt] != "") ? config["emoteCancelTarget" . slotInt] : ("Numpad" . slotInt)
    emoteCancel(targetKey, slotInt)
}

SelectEmoteSlotCallback(WebView, slot) {
    SelectEmoteCancelSlot(slot)
}

OnExit((*) => EmoteWheelOverlay.Shutdown())
