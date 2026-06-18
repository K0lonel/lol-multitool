#Requires AutoHotkey v2.0
#Include Base64.ahk

class LCU {
    static Token := ""
    static App_URL := ""
    static Web_URL := ""
    static App_Port := ""
    static Web_Port := "2999"
    static Host := "https://127.0.0.1:"
    static Query := "SELECT CommandLine FROM Win32_Process WHERE Name = 'LeagueClientUx.exe'"
    static WMI := ""

    static Initialize() {
        if (!ProcessExist("LeagueClientUx.exe")) {
            LCU.Token := ""
            LCU.App_Port := ""
            LCU.App_URL := ""
            LCU.Web_URL := ""
            return false
        }

        if (LCU.WMI == "") {
            try {
                LCU.WMI := ComObjGet("winmgmts:\\.\root\cimv2")
            } catch {
                return false
            }
        }
        
        try {
            Processes := LCU.WMI.ExecQuery(LCU.Query)
            for Process in Processes {
                cmd := Process.CommandLine
                if (IsSet(cmd) && cmd != "") {
                    LCU.App_Port := LCU.RegExFind(cmd, "--app-port=(\d+)")
                    LCU.App_URL := LCU.Host LCU.App_Port
                    LCU.Web_URL := LCU.Host LCU.Web_Port
                    LCU.Token := Base64.Encode("riot:" LCU.RegExFind(cmd, "--remoting-auth-token=([^\s`"`"]+)"))
                    return true
                }
            }
        } catch {
            ; ignore WMI errors
        }
        
        LCU.Token := ""
        LCU.App_Port := ""
        LCU.App_URL := ""
        LCU.Web_URL := ""
        return false
    }
    
    static RegExFind(haystack, needle) {
        RegExMatch(haystack, needle, &match)
        return match[1]
    }
}