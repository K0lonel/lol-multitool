#Requires AutoHotkey v2.0

global config := Map()

InitializeConfig() {
    global config
    
    defaultConfig := Map(
        "autoAccept", True,
        "autoReport", True,
        "acceptDelay", 0,
        "reportCategories", ["LEAVING_AFK", "ASSISTING_ENEMY_TEAM", "THIRD_PARTY_TOOLS", "RANK_MANIPULATION", "BOTTING", "VERBAL_ABUSE", "INAPPROPRIATE_NAME"],
        "reportComment", "tried to lose",
        "autoPickBenchEnabled", False,
        "autoPickBenchIds", Array(),
        "favoriteChampIds", Array(),
        "foldSniper", False,
        "foldAccept", False,
        "foldReport", False,
        "blacklistEnabled", True,
        "blacklist", Array(),
        "foldBlacklist", False,
        "autoDisenchantChampionsEnabled", False,
        "autoDisenchantWardsEnabled", False,
        "autoHonorerEnabled", False,
        "autoSkipPreEndEnabled", False,
        "champMessagesEnabled", True,
        "emoteCancelEnabled", True,
        "emoteCancelDelay", 50,
        "emoteCancelRightClick", True,
        "emoteCancelHoldKey", "XButton1",
        "emoteCancelTriggerKey", "MButton",
        "emoteCancelActiveSlot", 1,
        "emoteCancelTarget1", "Numpad1",
        "emoteCancelTarget2", "Numpad2",
        "emoteCancelTarget3", "Numpad3",
        "emoteCancelTarget4", "Numpad4",
        "emoteCancelTarget5", "Numpad5",
        "foldDisenchant", False,
        "foldHonorer", False,
        "foldSkipPreEnd", False,
        "foldChampMessages", False,
        "foldEmoteCancel", False,
        "autoAcceptSilent", False,
        "autoReportSilent", False,
        "autoSkipPreEndSilent", False,
        "blacklistSilent", False,
        "champSelectHelperSilent", False,
        "autoHonorerSilent", False,
        "disenchantSilent", False,
        "emoteCancelSilent", False
    )

    if (!FileExist("config.json")) {
        config := defaultConfig
        SaveConfig()
        return
    }

    try {
        config := JSON.Load(FileRead("config.json"))
    } catch {
        config := defaultConfig
        SaveConfig()
        return
    }

    modified := false
    for key, defaultValue in defaultConfig {
        if (!config.Has(key)) {
            config[key] := defaultValue
            modified := true
        }
    }

    if (modified) {
        SaveConfig()
    }
}

SaveConfig() {
    global config
    try {
        fileObj := FileOpen("config.json", "w", "UTF-8")
        fileObj.Write(JSON.Dump(config, True))
        fileObj.Close()
    } catch Error as e {
        try {
            LogToWeb("Failed to save config.json to disk: " e.Message, "error")
        } catch {
            OutputDebug("Failed to save config.json to disk: " e.Message "`n")
        }
    }
}
