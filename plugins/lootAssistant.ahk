#Requires AutoHotkey v2.0
#Include ../lol.ahk

RunMassDisenchant(silent := unset, forceChamps := unset, forceWards := unset) {
    global config
    try {
        isSilent := IsSet(silent) ? silent : (config.Has("disenchantSilent") && config["disenchantSilent"])
        
        champsEnabled := IsSet(forceChamps) ? forceChamps : (config.Has("autoDisenchantChampionsEnabled") && config["autoDisenchantChampionsEnabled"])
        wardsEnabled := IsSet(forceWards) ? forceWards : (config.Has("autoDisenchantWardsEnabled") && config["autoDisenchantWardsEnabled"])
        
        if (!champsEnabled && !wardsEnabled) {
            if (!isSilent)
                LogToWeb("Mass Disenchant: No options are enabled. Enable Champion and/or Ward disenchanting first.", "warning")
            return
        }

        lootList := APICall("GET", "/lol-loot/v1/player-loot")
        if (!IsObject(lootList) || Type(lootList) != "Array") {
            if (!isSilent)
                LogToWeb("Mass Disenchant: Failed to fetch player loot.", "error")
            return
        }
        
        disenchantCount := 0
        blueEssenceGained := 0
        orangeEssenceGained := 0
        
        for item in lootList {
            if (!IsObject(item) || !item.Has("type") || !item.Has("lootId") || !item.Has("count"))
                continue
                
            lootType := item["type"]
            ; Allow champion shards and ward skin shards depending on toggles
            isChamp := (lootType == "CHAMPION" || lootType == "CHAMPION_RENTAL")
            isWard := (InStr(lootType, "WARD") == 1)
            
            if (isChamp && !champsEnabled)
                continue
            if (isWard && !wardsEnabled)
                continue
            if (!isChamp && !isWard)
                continue
                
            count := item["count"]
            if (count <= 0)
                continue
                
            lootId := item["lootId"]
            recipeName := item.Has("disenchantRecipeName") && item["disenchantRecipeName"] != "" ? item["disenchantRecipeName"] : (lootType . "_disenchant")
            disenchantValue := item.Has("disenchantValue") ? item["disenchantValue"] : 0
            
            ; Get currency name and track gains
            disenchantLootName := item.Has("disenchantLootName") ? item["disenchantLootName"] : ""
            currencyName := "BE"
            if (disenchantLootName == "CURRENCY_cosmetic" || isWard) {
                currencyName := "OE"
            }
            
            itemName := item.Has("itemDesc") && item["itemDesc"] != "" ? item["itemDesc"] : lootId
            
                
            ; POST /lol-loot/v1/recipes/{recipeName}/craft?repeat={count} with body [lootId]
            url := "/lol-loot/v1/recipes/" . recipeName . "/craft?repeat=" . count
            body := [lootId]
            
            res := APICall("POST", url, JSON.Dump(body))
            if (IsObject(res) && res.Has("error")) {
                if (!isSilent)
                    LogToWeb("Mass Disenchant: Failed to disenchant " . itemName . ". Status: " . res["status"], "error")
            } else {
                disenchantCount += count
                if (currencyName == "OE") {
                    orangeEssenceGained += (disenchantValue * count)
                } else {
                    blueEssenceGained += (disenchantValue * count)
                }
                if (!isSilent)
                    LogToWeb("Mass Disenchant: Successfully disenchanted " . itemName . "! (Gained " . (disenchantValue * count) . " " . currencyName . ")", "success")
            }
        }
        
        if (disenchantCount > 0) {
            msg := "Mass Disenchant: Completed! Disenchanted " . disenchantCount . " shards."
            if (blueEssenceGained > 0)
                msg .= " Gained " . blueEssenceGained . " BE."
            if (orangeEssenceGained > 0)
                msg .= " Gained " . orangeEssenceGained . " OE."
            LogToWeb(msg, "success")
        } else {
            if (!isSilent)
                LogToWeb("Mass Disenchant: No shards found to disenchant for enabled types.", "info")
        }
    } catch Error as e {
        if (!isSilent)
            LogToWeb("Mass Disenchant: Error during disenchant: " . e.Message, "error")
    }
}
