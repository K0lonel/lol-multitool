#Requires AutoHotkey v2.0
#Include ../lol.ahk
plugins.Push(smartAutoHonorer)

smartAutoHonorer() {
    global config, gameflow, friend_puuid, autoHonorCompleted
    static lastHonorGameId := 0
    
    if (!config.Has("autoHonorerEnabled") || !config["autoHonorerEnabled"]) {
        autoHonorCompleted := true ; If disabled, don't block skipper
        return
    }
    
    if (gameflow != "PreEndOfGame") {
        autoHonorCompleted := false
        return
    }
    
    if (autoHonorCompleted)
        return
        
    try {
        room := APICall("GET", "/lol-honor-v2/v1/room")
        if (!IsObject(room) || !room.Has("gameId") || !room.Has("available") || !room.Has("summoners")) {
            ; Room not ready or doesn't exist
            return
        }
        
        gameId := room["gameId"]
        
        ; If we already processed this gameId, mark completed and return
        if (gameId == lastHonorGameId) {
            autoHonorCompleted := true
            return
        }
        
        if (room["available"] == false) {
            LogToWeb("Auto-Honorer: Honoring is not available for this game.", "warning")
            lastHonorGameId := gameId
            autoHonorCompleted := true
            return
        }
        
        summoners := room["summoners"]
        if (Type(summoners) != "Array" || summoners.Length == 0) {
            LogToWeb("Auto-Honorer: No teammates found in the honor room.", "warning")
            lastHonorGameId := gameId
            autoHonorCompleted := true
            return
        }
        
        ; Fetch lobby members to identify premades
        premades := Map()
        try {
            lobby := APICall("GET", "/lol-lobby/v2/lobby")
            if (IsObject(lobby) && lobby.Has("members")) {
                members := lobby["members"]
                if (Type(members) == "Array") {
                    for member in members {
                        if (member.Has("puuid")) {
                            premades[member["puuid"]] := true
                        }
                    }
                }
            }
        } catch {
            ; Lobby call might fail if lobby already destroyed, ignore
        }
        
        ; Filter eligible candidates (omit friends and premades)
        candidates := Array()
        for player in summoners {
            if (!player.Has("puuid") || !player.Has("summonerId"))
                continue
                
            pPuuid := player["puuid"]
            pId := player["summonerId"]
            
            pName := ""
            if (player.Has("gameName") && player["gameName"] != "")
                pName := player["gameName"]
            else if (player.Has("summonerName") && player["summonerName"] != "")
                pName := player["summonerName"]
            else if (player.Has("displayName") && player["displayName"] != "")
                pName := player["displayName"]
            else
                pName := "Teammate"
                
            pTag := player.Has("tagLine") ? player["tagLine"] : ""
            fullName := pName . (pTag != "" ? "#" . pTag : "")
            
            ; Omit friends
            if (friend_puuid.Has(pPuuid)) {
                LogToWeb("Auto-Honorer: Filtering out friend " . fullName, "debug")
                continue
            }
            
            ; Omit premades/lobby members
            if (premades.Has(pPuuid)) {
                LogToWeb("Auto-Honorer: Filtering out premade " . fullName, "debug")
                continue
            }
            
            candidates.Push(Map("summonerId", pId, "fullName", fullName))
        }
        
        if (candidates.Length == 0) {
            LogToWeb("Auto-Honorer: No eligible teammates to honor (all are friends or lobby members). Skipping.", "warning")
            lastHonorGameId := gameId
            autoHonorCompleted := true
            return
        }
        
        ; Pick a random candidate
        randomIndex := Random(1, candidates.Length)
        targetPlayer := candidates[randomIndex]
        targetId := targetPlayer["summonerId"]
        targetFullName := targetPlayer["fullName"]
        
        ; Pick a random honor type: COOL, SHOTCALLER, HEART
        honorTypes := ["COOL", "SHOTCALLER", "HEART"]
        randomHonorType := honorTypes[Random(1, 3)]
        
        LogToWeb("Auto-Honorer: Sending honor (" . randomHonorType . ") to " . targetFullName . "...", "info")
        
        body := Map(
            "gameId", gameId,
            "summonerId", targetId,
            "honorCategory", randomHonorType
        )
        
        res := APICall("POST", "/lol-honor-v2/v1/honor-player", JSON.Dump(body))
        if (IsObject(res) && res.Has("error")) {
            LogToWeb("Auto-Honorer: Failed to submit honor. Status: " . res["status"], "error")
        } else {
            LogToWeb("Auto-Honorer: Successfully honored " . targetFullName . "!", "success")
        }
        
        lastHonorGameId := gameId
        autoHonorCompleted := true
    } catch Error as e {
        LogToWeb("Auto-Honorer: Error processing honor room: " . e.Message, "error")
        ; Set autoHonorCompleted to true on error to avoid blocking the skipper
        autoHonorCompleted := true
    }
}
