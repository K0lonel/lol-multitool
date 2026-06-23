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
        tempHistory := APICall("GET", "/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=0&endIndex=9")
        if (!IsObject(tempHistory) || !tempHistory.Has("games") || !tempHistory["games"].Has("games")) {
            MyWindow.ExecuteScriptAsync("onRecentPlayersLoaded([])")
            return
        }
        
        recentPlayers := Array()
        seenPlayers := Map()
        
        for index, game in tempHistory["games"]["games"] {
            gameId := String(game["gameId"])
            identities := ""
            if (game.Has("participantIdentities") && IsObject(game["participantIdentities"]) && game["participantIdentities"].Length > 1) {
                identities := game["participantIdentities"]
            } else if (gameIdentitiesCache.Has(gameId)) {
                identities := gameIdentitiesCache[gameId]
            } else {
                detailed_history := APICall("GET", "/lol-match-history/v1/games/" gameId)
                if (IsObject(detailed_history) && detailed_history.Has("participantIdentities")) {
                    identities := detailed_history["participantIdentities"]
                    gameIdentitiesCache[gameId] := identities
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
                                recentPlayers.Push(Map(
                                    "gameName", player["gameName"], 
                                    "tagLine", player["tagLine"], 
                                    "nameWithTag", nameWithTag
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
