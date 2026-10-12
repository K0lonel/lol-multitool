#Requires AutoHotkey v2.0
PluginManager.Register("blacklist", "", 0)

GetRecentPlayersCallback(WebView) {
    global match_history
    try {
        ; Reuse globally cached match_history if available, otherwise fetch
        matchesObj := match_history
        if (!IsObject(matchesObj) || !matchesObj.Has("games") || !matchesObj["games"].Has("games")) {
            matchesObj := LeagueAPI.GetCurrentSummonerMatches(0, 9)
        }
        
        if (!IsObject(matchesObj) || !matchesObj.Has("games") || !matchesObj["games"].Has("games")) {
            MyWindow.ExecuteScriptAsync("onRecentPlayersLoaded([])")
            return
        }
        
        recentPlayers := Array()
        seenPlayers := Map()
        
        for index, game in matchesObj["games"]["games"] {
            if (A_Index > 9)
                break
                
            gameId := String(game["gameId"])
            identities := ""
            participantsList := ""
            
            if (game.Has("participantIdentities") && IsObject(game["participantIdentities"]) && game["participantIdentities"].Length > 1) {
                identities := game["participantIdentities"]
            }
            if (game.Has("participants") && IsObject(game["participants"]) && game["participants"].Length > 1) {
                participantsList := game["participants"]
            }
            
            if (!IsObject(identities) || !IsObject(participantsList)) {
                detailed_history := GetCachedGameDetails(gameId)
                if (IsObject(detailed_history)) {
                    if (detailed_history.Has("participantIdentities"))
                        identities := detailed_history["participantIdentities"]
                    if (detailed_history.Has("participants"))
                        participantsList := detailed_history["participants"]
                }
            }
            
            participantChampMap := Map()
            if (IsObject(participantsList)) {
                for p in participantsList {
                    if (IsObject(p) && p.Has("participantId") && p.Has("championId")) {
                        participantChampMap[String(p["participantId"])] := p["championId"]
                    }
                }
            }
            
            if (IsObject(identities)) {
                for pIndex, participant in identities {
                    if (IsObject(participant) && participant.Has("player")) {
                        player := participant["player"]
                        if (IsObject(player) && player.Has("gameName")) {
                            nameWithTag := player["gameName"] "#" player["tagLine"]
                            if (!seenPlayers.Has(nameWithTag)) {
                                seenPlayers[nameWithTag] := true
                                pId := participant.Has("participantId") ? String(participant["participantId"]) : ""
                                champId := (pId != "" && participantChampMap.Has(pId)) ? participantChampMap[pId] : 0
                                
                                recentPlayers.Push(Map(
                                    "gameName", player["gameName"], 
                                    "tagLine", player["tagLine"], 
                                    "nameWithTag", nameWithTag,
                                    "championId", champId
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        MyWindow.ExecuteScriptAsync("onRecentPlayersLoaded(" JSON.Dump(recentPlayers) ")")
    } catch Error as e {
        LogToWeb("Error fetching recent players: " e.Message, "error", "blacklistSilent")
        MyWindow.ExecuteScriptAsync("onRecentPlayersLoaded([])")
    }
}
