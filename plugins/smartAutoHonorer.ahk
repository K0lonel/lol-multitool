#Requires AutoHotkey v2.0
#Include ../lol.ahk
plugins.Push(smartAutoHonorer)

smartAutoHonorer() {
    global config, gameflow, autoHonorCompleted
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
        ballot := APICall("GET", "/lol-honor-v2/v1/ballot")
        if (!IsObject(ballot) || !ballot.Has("gameId")) {
            ; Ballot not ready or doesn't exist
            return
        }
        
        gameId := ballot["gameId"]
        
        ; If we already processed this gameId, mark completed and return
        if (gameId == lastHonorGameId) {
            autoHonorCompleted := true
            return
        }
        
        ; If already honored someone in this ballot, skip
        if (ballot.Has("honoredPlayers") && IsObject(ballot["honoredPlayers"]) && ballot["honoredPlayers"].Length > 0) {
            LogHonorer("Auto-Honorer: You have already honored players for this match.", "info")
            lastHonorGameId := gameId
            autoHonorCompleted := true
            return
        }
        
        ; Read available votes count
        votesCount := 1
        if (ballot.Has("votePool") && IsObject(ballot["votePool"]) && ballot["votePool"].Has("votes")) {
            votesCount := ballot["votePool"]["votes"]
        }
        
        opponents := Array()
        allies := Array()
        
        if (ballot.Has("eligibleOpponents") && IsObject(ballot["eligibleOpponents"])) {
            opponents := ballot["eligibleOpponents"]
        }
        if (ballot.Has("eligibleAllies") && IsObject(ballot["eligibleAllies"])) {
            allies := ballot["eligibleAllies"]
        }
        
        ; Gather target players based on votesCount
        targets := Array()
        
        ; 1. Pick unique opponents first
        oppsTemp := opponents.Clone()
        while (oppsTemp.Length > 0 && targets.Length < votesCount) {
            randIdx := Random(1, oppsTemp.Length)
            targets.Push(Map("player", oppsTemp[randIdx], "isOpponent", true))
            oppsTemp.RemoveAt(randIdx)
        }
        
        ; 2. Fall back to unique allies if we have remaining votes
        alliesTemp := allies.Clone()
        while (alliesTemp.Length > 0 && targets.Length < votesCount) {
            randIdx := Random(1, alliesTemp.Length)
            targets.Push(Map("player", alliesTemp[randIdx], "isOpponent", false))
            alliesTemp.RemoveAt(randIdx)
        }
        
        if (targets.Length == 0) {
            LogHonorer("Auto-Honorer: No eligible players found in the ballot to honor.", "warning")
            lastHonorGameId := gameId
            autoHonorCompleted := true
            return
        }
        
        LogHonorer("Auto-Honorer: Detected " . votesCount . " available vote(s). Processing honors...", "info")
        
        for idx, targetInfo in targets {
            targetPlayer := targetInfo["player"]
            isOpponent := targetInfo["isOpponent"]
            
            targetId := targetPlayer["summonerId"]
            targetPuuid := targetPlayer["puuid"]
            
            targetName := ""
            if (targetPlayer.Has("summonerName") && targetPlayer["summonerName"] != "")
                targetName := targetPlayer["summonerName"]
            else if (targetPlayer.Has("championName") && targetPlayer["championName"] != "")
                targetName := targetPlayer["championName"]
            else
                targetName := "Player"
                
            randomHonorType := "GG"
            entityType := isOpponent ? "opponent" : "ally"
            LogHonorer("Auto-Honorer: Sending honor (" . randomHonorType . ") to " . entityType . " " . targetName . "...", "info")
            
            body := Map(
                "summonerId", targetId,
                "puuid", targetPuuid,
                "honorType", randomHonorType,
                "gameId", gameId
            )
            
            res := APICall("POST", "/lol-honor-v2/v1/honor-player", JSON.Dump(body))
            if (IsObject(res) && res.Has("error")) {
                LogHonorer("Auto-Honorer: Failed to honor " . targetName . ". Status: " . res["status"], "error")
            } else {
                msg := ""
                if (IsObject(res)) {
                    msg := " Response: " . JSON.Dump(res)
                }
                LogHonorer("Auto-Honorer: Successfully honored " . entityType . " " . targetName . "!" . msg, "success")
            }
        }
        
        lastHonorGameId := gameId
        autoHonorCompleted := true
    } catch Error as e {
        LogHonorer("Auto-Honorer: Error processing honor ballot: " . e.Message, "error")
        autoHonorCompleted := true
    }
}

LogHonorer(msg, type := "info") {
    global config
    if (config.Has("autoHonorerSilent") && config["autoHonorerSilent"])
        return
    LogToWeb(msg, type)
}
