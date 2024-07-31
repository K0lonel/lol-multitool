;Environment Controls
;///////////////////////////////////////////////////////////////////////////////////////////
#Requires Autohotkey v2
#SingleInstance Force
#Include AHK Resources/WebView2.ahk
#Include AHK Resources/WebViewToo.ahk

ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("ScriptGroup", "ahk_pid" ScriptPID)

MyWindow := WebViewToo(,,, True)
MyWindow.OnEvent("Close", (*) => ExitApp())
MyWindow.Load("Pages/index.html")
MyWindow.Show("w1200 h800 Center", "LoL-App")
; MyWindow.AddHostObjectToScript("ahkButtonClick", {func:WebButtonClickEvent})
; MyWindow.AddCallBackToScript("CopyGlyphCode", CopyGlyphCodeEvent)
; MyWindow.AddCallBackToScript("Tooltip", WebTooltipEvent)
; MyWindow.AddCallbackToScript("ahkFormSubmit", FormSubmitHandler)



SetTimer(autoTFT, 1000)
; #HotIf WinActive("ahk_group ScriptGroup")
return

;///////////////////////////////////////////////////////////////////////////////////////////
WebButtonClickEvent(button) {
    MsgBox(button)
}

CopyGlyphCodeEvent(WebView, Title) {
	GlyphCode := "<span class='glyphicon glyphicon-" Title "' aria-hidden='true'></span>"
	MsgBox(A_Clipboard := GlyphCode, "OuterHTML Copied to Clipboard")
}

WebTooltipEvent(WebView, Msg) {
    ToolTip(Msg)
    SetTimer((*) => ToolTip(), -1000)
}


FormSubmitHandler(WebView, Form) => SetTimer((*) => FormSubmitEvent(WebView, Form), -1)
FormSubmitEvent(WebView, Form) {
    FormInfo := MyWindow.GetFormData(Form)
    MsgBox(WebViewToo.forEach(FormInfo))
}