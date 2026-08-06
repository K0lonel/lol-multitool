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
        static lastInitAttempt := 0
        if (A_TickCount - lastInitAttempt < 3000) {
            return false
        }
        lastInitAttempt := A_TickCount

        if (!ProcessExist("LeagueClientUx.exe")) {
            LCU.Clear()
            return false
        }

        ; 1. Try to read from the lockfile first (much faster and bypasses WMI)
        lockfilePath := LCU.GetLockfilePath()
        if (lockfilePath != "" && FileExist(lockfilePath)) {
            try {
                lockfileContent := FileRead(lockfilePath, "UTF-8")
                parts := StrSplit(lockfileContent, ":")
                if (parts.Length >= 5) {
                    LCU.App_Port := parts[3]
                    LCU.App_URL := LCU.Host LCU.App_Port
                    LCU.Web_URL := LCU.Host LCU.Web_Port
                    LCU.Token := Base64.Encode("riot:" parts[4])
                    LogToWeb("LCU connection: Found credentials via lockfile.", "success")
                    return true
                }
            } catch {
                ; Lockfile read error (e.g. sharing violation or blank file)
                ; Fall through to WMI query
            }
        }

        ; 2. Fallback to WMI query if lockfile lookup failed
        if (LCU.WMI == "") {
            try {
                LCU.WMI := ComObjGet("winmgmts:\\.\root\cimv2")
            } catch {
                LCU.Clear()
                return false
            }
        }
        
        try {
            Processes := LCU.WMI.ExecQuery(LCU.Query)
            for Process in Processes {
                cmd := Process.CommandLine
                if (IsSet(cmd) && cmd != "") {
                    port := LCU.RegExFind(cmd, "--app-port=(\d+)")
                    token := LCU.RegExFind(cmd, "--remoting-auth-token=([^\s`"`"]+)")
                    
                    if (port != "" && token != "") {
                        LCU.App_Port := port
                        LCU.App_URL := LCU.Host LCU.App_Port
                        LCU.Web_URL := LCU.Host LCU.Web_Port
                        LCU.Token := Base64.Encode("riot:" token)
                        LogToWeb("LCU connection: Found credentials via WMI process query.", "success")
                        return true
                    }
                }
            }
        } catch {
            ; ignore WMI errors
        }
        
        LCU.Clear()
        return false
    }

    static GetLockfilePath() {
        ; A. Try to find the path via ProcessGetPath
        try {
            if (pid := ProcessExist("LeagueClientUx.exe")) {
                uxPath := ProcessGetPath(pid)
                if (uxPath != "") {
                    return RegExReplace(uxPath, "\\[^\\]+$") "\lockfile"
                }
            }
        } catch {
            ; ProcessGetPath might fail if client runs with higher privilege level
        }

        ; B. Check common registry keys where the game is installed
        registryKeys := [
            ["HKCU\Software\Riot Games\Install Locations", "league_of_legends.live"],
            ["HKLM\SOFTWARE\WOW6432Node\Riot Games, Inc\League of Legends", "InstallPath"],
            ["HKLM\SOFTWARE\Riot Games, Inc\League of Legends", "InstallPath"]
        ]
        for keyInfo in registryKeys {
            try {
                dir := RegRead(keyInfo[1], keyInfo[2])
                if (dir != "" && FileExist(dir "\lockfile")) {
                    return dir "\lockfile"
                }
            } catch {
                ; Key not found or file not accessible
            }
        }

        ; C. Hardcoded standard paths
        defaultPaths := [
            "C:\Riot Games\League of Legends\lockfile",
            "D:\Riot Games\League of Legends\lockfile"
        ]
        for path in defaultPaths {
            if FileExist(path) {
                return path
            }
        }
        return ""
    }

    static Clear() {
        LCU.Token := ""
        LCU.App_Port := ""
        LCU.App_URL := ""
        LCU.Web_URL := ""
    }
    
    static RegExFind(haystack, needle) {
        if (RegExMatch(haystack, needle, &match)) {
            return match[1]
        }
        return ""
    }
}