WBCoalition.LootDistributor = {}
local LootDistributor = WBCoalition.LootDistributor

local itemList = {
    -- Azuregos
    "Crystal Adorned Crown", "Drape of Benediction", "Puissant Cape", "Unmelting Ice Girdle",
    "Leggins of Arcane Supremacy", "Snowblind Shoes", "Cold Snap", "Fand of the Mystics", "Eshhandar's Left Claw",
    "Typhoon", "Mature Blue Dragon Sinew", -- Kazzak
    "Infernal Headcage", "Blazefury Medallion", "Eskhandar's Pelt", "Blacklight Bracer", "Doomhide Gauntlets",
    "Flayed Doomguard Belt", "Fel Infused Leggins", "Ring of Entropy", "Empyrean Demolisher", "Amberseal Keeper",
    "The Eye of Shadow", -- Lethon
    "Deviate Growth Cap", "Black Bark Wristbands", "Gauntlets of the Shining Light", "Belt of the Dark Bog",
    "Dark Heart Pants", "Malignant Footguards", -- Emeriss
    "Circlet of Restless Dreams", "Dragonheart Necklace", "Ring of the Unliving", "Boots of the Endless Moor",
    "Polished Ironwood Crossbow", -- Taerar
    "Unnatural Leather Spaulders", "Mendicant's Slippers", "Boots of Fright", "Mindtear Band", "Nightmare Blade",

    -- Ysondre
    "Acid Inscribed Pauldrons", "Jade Inlaid Vestments", "Leggins of the Demented Mind", "Strangely Glyphed Legplates",
    "Hibernation Crystal", "Emerald Dragonfang", -- All emerald dragons
    "Green Dragonskin Cloak", "Dragonspur Wraps", "Dragonbone Wristguards", "Gloves of Delusional Power",
    "Ancient Corroded Leggins", "Acid Inscribed Greaves", "Trance Stone", "Nightmare Engulfed Object",
    "Hammer of Bestial Fury", "Staff of Rampant Growth"
}

local LOOT_METHOD_BUY = 'buy'
local LOOT_METHOD_ROLL = 'roll'

lootMethodMap = {
    ['+'] = LOOT_METHOD_BUY,
    [' +'] = LOOT_METHOD_BUY,
    ['buy'] = LOOT_METHOD_BUY,
    [' buy'] = LOOT_METHOD_BUY,
    ['points'] = LOOT_METHOD_BUY,
    [' points'] = LOOT_METHOD_BUY,
    ['for points'] = LOOT_METHOD_BUY,
    [' for points'] = LOOT_METHOD_BUY,
    ['roll'] = LOOT_METHOD_ROLL,
    [' roll'] = LOOT_METHOD_ROLL,
    ['/roll'] = LOOT_METHOD_ROLL,
    [' /roll'] = LOOT_METHOD_ROLL
}

local DIALOG_CONFIRM_CLEAR = "WBC_DIALOG_CONFIRM_CLEAR_LOOT_LOG"

local isWBossLoot = {}

for _, item in pairs(itemList) do isWBossLoot[item] = true end

local zoneMap = {}

local notEligibleFor = {}

local function showUsage()
    WBCoalition:Log('/wbc |cffa334ee[Item Link]|r +')
    WBCoalition:Log('or')
    WBCoalition:Log('/wbc |cffa334ee[Item Link]|r roll')
end

function LootDistributor:ClearLog() StaticPopup_Show(DIALOG_CONFIRM_CLEAR) end

function LootDistributor:SetLootLogText()
    local texts = {}
    local lootLog = WBCCache.lootLog
    for i=#lootLog,1,-1 do
        itemLog = lootLog[i]
        text = date('%d/%m/%Y', itemLog.time) .. ',' .. itemLog.boss .. ',' .. itemLog.item .. ',FALSE,' ..
                   itemLog.player
        table.insert(texts, text)
    end
    WBCLootLogEditBox:SetText(table.concat(texts, '\n'))
end

function LootDistributor:OnCommand(cmd)
    local linkEndIndex = string.find(cmd, '|r')
    local cmdValid = cmd ~= '' and linkEndIndex
    if cmdValid then
        local cmdMethod = cmd:sub(linkEndIndex+2, -1)
        if cmdMethod then
            local lootMethod = lootMethodMap[cmdMethod]
            if lootMethod then
                if IsInRaid() and (UnitIsRaidOfficer('player') or UnitIsGroupLeader('player')) then
                    Table:ClearPluses()
                    local msg = ' /roll'
                    if lootMethod == LOOT_METHOD_BUY then
                        msg = ' + in the raid chat or whisper if you want to buy with points'
                    end
                    SendChatMessage(cmd:sub(1,linkEndIndex+1) .. msg, 'RAID_WARNING')
                    if lootMethod == LOOT_METHOD_BUY then
                        SendChatMessage('if you want to donate add a message e.g.: "+ donate to '.. UnitName('player') ..'"', 'RAID')
                    end
                else
                    WBCoalition:LogError("You can't do raid warnings")
                end
            else
                cmdValid = false
            end
        else
            cmdValid = false
        end
    end

    if not cmdValid then
        WBCoalition:LogError('Wrong command, usage:')
        showUsage()
    end
end

function LootDistributor:OnLootMessage(...)
    local message, _, _, _, player = ...
    if string.find(message, "receive") then
        local playerNameUpper = string.upper(player)
        local startIndex, endIndex = string.find(message, "%[.+%]")
        local itemName = string.sub(message, startIndex + 1, endIndex - 1)

        if not isWBossLoot[itemName] then return end

        local zone = GetRealZoneText()
        local bossName = '<Unknown>'
        for _, name in pairs(WBCoalition.BOSS_NAMES) do
            if WBCCache.tracks[name] and WBCCache.tracks[name].zone == zone then bossName = name end
        end

        table.insert(WBCCache.lootLog,
                     {zone = zone, item = itemName, player = player, boss = bossName, time = GetServerTime()})
    end
end

function LootDistributor:OnLootOpened()
    if not IsMasterLooter() then return end
    local numItems = GetNumLootItems()
    local lootSourceId = GetLootSourceInfo(1)

    local targetName = GetUnitName('target')

    local isWorldBoss = false
    for i = 1, #WBCoalition.BOSS_NAMES do if targetName == WBCoalition.BOSS_NAMES[i] then isWorldBoss = true end end

    if not isWorldBoss then return end

    if notEligibleFor[targetName] then return end

    notEligibleFor[targetName] = {}

    WBCoalition:Log('To distribute loot you can use commands:')
    showUsage()

    for itemIndex = 1, numItems do
        local itemIcon, itemName, _, _, quality = GetLootSlotInfo(itemIndex)
        if quality >= GetLootThreshold() then
            local isEligible = {}
            local eligibleNum = 0
            local j = 1
            repeat
                local candidateName = GetMasterLootCandidate(itemIndex, j)
                if candidateName then
                    isEligible[candidateName] = true
                    eligibleNum = eligibleNum + 1
                end
                j = j + 1
            until not candidateName

            for j = 1, 40 do
                local raiderName = GetRaidRosterInfo(j)
                if not isEligible[raiderName] then table.insert(notEligibleFor[targetName], raiderName) end
            end
            SendChatMessage(eligibleNum .. ' people eligible for ' .. targetName .. ' loot.', 'RAID')
            if #notEligibleFor[targetName] > 0 then
                SendChatMessage('Listing NOT eligible: ' .. table.concat(notEligibleFor[targetName], ', '), 'RAID')
            end
            return
        end
    end

end

StaticPopupDialogs[DIALOG_CONFIRM_CLEAR] = {
    text = "Are you sure you want to clear the loot log?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        WBCCache.lootLog = {}
        WBCLootLogEditBox:SetText('')
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}
