#Requires AutoHotkey v2.0
#Include API.ahk

class LeagueAPI {
    static GetCurrentSummoner() {
        return APICall("GET", "/lol-summoner/v1/current-summoner")
    }

    static GetFriends() {
        return APICall("GET", "/lol-chat/v1/friends")
    }

    static GetGameflowPhase() {
        return APICall("GET", "/lol-gameflow/v1/gameflow-phase")
    }

    static GetCurrentSummonerMatches(begIndex := 0, endIndex := 49) {
        return APICall("GET", "/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=" begIndex "&endIndex=" endIndex)
    }

    static GetChampionsMinimal(summonerId := 0) {
        if (summonerId > 0) {
            res := APICall("GET", "/lol-champions/v1/inventories/" summonerId "/champions-minimal")
            if (Type(res) == "Array" && res.Length > 0)
                return res
        }
        resFallback := APICall("GET", "/lol-champions/v1/owned-champions-minimal")
        if (Type(resFallback) == "Array" && resFallback.Length > 0)
            return resFallback
        return APICall("GET", "/lol-champions/v1/inventories/champions-minimal")
    }

    static QuitLobbySession() {
        return APICall("POST", "/lol-lobby-team-builder/champ-select/v1/session/quit", "{}")
    }

    static QuitProcess() {
        return APICall("POST", "/process-control/v1/process/quit", "{}")
    }

    static SwapBenchChampion(champId) {
        champIdInt := Integer(champId)
        return APICall("POST", "/lol-champ-select/v1/session/bench/swap/" champIdInt, "{}")
    }

    static UpdateMySelection(body) {
        return APICall("PATCH", "/lol-champ-select/v1/session/my-selection", body)
    }

    static AcceptReadyCheck() {
        return APICall("POST", "/lol-matchmaking/v1/ready-check/accept")
    }

    static GetGameDetails(gameId) {
        return APICall("GET", "/lol-match-history/v1/games/" gameId)
    }

    static SubmitPlayerReport(reportData) {
        return APICall("POST", "/lol-player-report-sender/v1/match-history-reports", reportData)
    }

    static SkipPreEndOfGame() {
        return APICall("POST", "/lol-pre-end-of-game/v1/skip-pre-end-of-game")
    }

    static GetChampSelectSession() {
        return APICall("GET", "/lol-champ-select/v1/session")
    }

    static GetSummonerByPuuid(puuid) {
        return APICall("GET", "/lol-summoner/v1/summoners/by-puuid/" puuid)
    }

    static GetPlayerLoot() {
        return APICall("GET", "/lol-loot/v1/player-loot")
    }

    static CraftLoot(recipeName, count, body) {
        return APICall("POST", "/lol-loot/v1/recipes/" recipeName "/craft?repeat=" count, body)
    }

    static RestartUX() {
        return APICall("POST", "/riotclient/kill-and-restart-ux", "{}")
    }

    static ReconnectGameflow() {
        return APICall("POST", "/lol-gameflow/v1/reconnect")
    }

    static GetHonorBallot() {
        return APICall("GET", "/lol-honor-v2/v1/ballot")
    }

    static HonorPlayer(body) {
        return APICall("POST", "/lol-honor-v2/v1/honor-player", body)
    }

    static SendChatMessage(conversationId, bodyText) {
        body := Map("body", bodyText, "type", "chat")
        return APICall("POST", "/lol-chat/v1/conversations/" conversationId "/messages", JSON.Dump(body))
    }
}
