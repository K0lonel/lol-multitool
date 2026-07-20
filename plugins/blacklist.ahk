#Requires AutoHotkey v2.0
#Include ../lol.ahk

global gameIdentitiesCache := Map()

plugins.Push(blacklistPlugin)

blacklistPlugin() {
    ; Event-driven plugin, does not need periodic logic
}

GetRecentPlayersCallback(WebView) {
    global gameIdentitiesCache
    try {
        tempHistory := LeagueAPI.GetCurrentSummonerMatches(0, 9)
        if (!IsObject(tempHistory) || !tempHistory.Has("games") || !tempHistory["games"].Has("games")) {
            MyWindow.ExecuteScriptAsync("onRecentPlayersLoaded([])")
            return
        }
        
        recentPlayers := Array()
        seenPlayers := Map()
        
        for index, game in tempHistory["games"]["games"] {
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
                if (gameIdentitiesCache.Has(gameId)) {
                    cached := gameIdentitiesCache[gameId]
                    if (IsObject(cached) && HasProp(cached, "Has") && cached.Has("identities")) {
                        identities := cached["identities"]
                        participantsList := cached.Has("participants") ? cached["participants"] : ""
                    }
                }
                
                if (!IsObject(identities) || !IsObject(participantsList)) {
                    detailed_history := LeagueAPI.GetGameDetails(gameId)
                    if (IsObject(detailed_history)) {
                        if (detailed_history.Has("participantIdentities"))
                            identities := detailed_history["participantIdentities"]
                        if (detailed_history.Has("participants"))
                            participantsList := detailed_history["participants"]
                        
                        gameIdentitiesCache[gameId] := Map("identities", identities, "participants", participantsList)
                    }
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
