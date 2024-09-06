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

    static __New() {
        WMI := ComObjGet("winmgmts:\\.\root\cimv2")
        LCU.Initialize(WMI)
    }
    
    static Initialize(WMI) {
        while(!IsSet(cmd))
        {
            Processes := WMI.ExecQuery(LCU.Query)
            for Process in Processes
                cmd := Process.CommandLine
        }
        
        LCU.App_Port := LCU.RegExFind(cmd, "--app-port=(\d+)")
        LCU.App_URL := LCU.Host LCU.App_Port
        LCU.Web_URL := LCU.Host LCU.Web_Port
        LCU.Token := Base64.Encode("riot:" LCU.RegExFind(cmd, "--remoting-auth-token=([^\s`"`"]+)"))
    }
    
    static RegExFind(haystack, needle) {
        RegExMatch(haystack, needle, &match)
        return match[1]
    }
}