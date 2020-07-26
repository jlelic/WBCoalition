WBCoalition.LootDistributor = {}
local LootDistributor = WBCoalition.LootDistributor

local function uniq(t)
    local result = {}
    local hash = {}

    for _, v in pairs(t) do
        if (not hash[v]) then
            table.insert(result, v)
            hash[v] = true
        end
    end

    return result
end

local LOOT_METHOD_BUY = 'buy'
local LOOT_METHOD_ROLL = 'roll'

local lootMethodMap = {
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

local isSharedGreenDragonLoot = {
    [20579] = true,
    [20615] = true,
    [20616] = true,
    [20618] = true,
    [20617] = true,
    [20619] = true,
    [20582] = true,
    [20644] = true,
    [20580] = true,
    [20581] = true
}

local allItemIds = {}
local dropsFrom = {}
local isRoll = false

for boss, data in pairs(WBCoalition.BOSS_DATA) do
    for _, itemId in ipairs(data.loot) do
        table.insert(allItemIds, itemId)

        if isSharedGreenDragonLoot[itemId] then
            dropsFrom[itemId] = data.color .. '4 Dragons'
        else
            dropsFrom[itemId] = data.color .. boss
        end
    end
end

allItemIds = uniq(allItemIds)

local zoneMap = {}

local notEligibleFor = {}

local function showUsage()
    WBCoalition:Log('/wbc |cffa334ee[Item Link]|r +')
    WBCoalition:Log('or')
    WBCoalition:Log('/wbc |cffa334ee[Item Link]|r roll')
end

local function getInterestedNames(itemId)
    local result = {}

    for name, data in pairs(WBCDB.players) do
        for _, intestedIn in ipairs(data.lootInterest) do
            if itemId == intestedIn then table.insert(result, name) end
        end
    end

    return result
end

local function isWBossLoot(itemName)
    if not WBCCache.isWBossLoot then
        WBCCache.isWBossLoot = {}
        for _, itemId in ipairs(allItemIds) do
            local itemName = GetItemInfo(itemId)
            WBCCache.isWBossLoot[itemName] = true
        end
    end

    return WBCCache.isWBossLoot[itemName]
end

local function recalculateBossLootRanks(lootRanks)
    for boss, data in pairs(WBCoalition.BOSS_DATA) do
        lootRanks[boss] = {}
        for _, itemId in ipairs(data.loot) do
            for player, _ in pairs(WBCDB.players) do
                if lootRanks[itemId][player] then
                    lootRanks[boss][player] = min(lootRanks[boss][player] or 99999, lootRanks[itemId][player])
                end
            end
        end
    end
end

function LootDistributor:ClearLog() StaticPopup_Show(DIALOG_CONFIRM_CLEAR) end

function LootDistributor:SetLootLogText()
    local texts = {}
    local lootLog = WBCCache.lootLog
    for i = #lootLog, 1, -1 do
        itemLog = lootLog[i]
        local playerPart = itemLog.player
        local mainName = WBCDB.altMap[itemLog.player]
        if mainName and mainName ~= itemLog.player then playerPart = mainName .. ',' .. itemLog.player end
        text = date('%d/%m/%Y', itemLog.time) .. ',' .. itemLog.boss .. ',' .. itemLog.item .. ',' .. (tostring(itemLog.isRoll or false)) ..
                   ',' .. playerPart
        table.insert(texts, text)
    end
    WBCLootLogEditBox:SetText(table.concat(texts, '\n'))
end

function LootDistributor:GetLootSource(itemId) return dropsFrom[itemId] end

function LootDistributor:RecalculateLootRanks()
    local lootRanks = {}

    for _, itemId in ipairs(allItemIds) do
        lootRanks[itemId] = {}
        local interestedPlayers = getInterestedNames(itemId)
        table.sort(interestedPlayers, WBCoalition.Table.Sorters['points'])
        for index, player in ipairs(interestedPlayers) do lootRanks[itemId][player] = index end
    end

    recalculateBossLootRanks(lootRanks)

    WBCDB.lootRanks = lootRanks
end

function LootDistributor:RecalculateRaidLootRanks(raidMap, raidLootRanks)
    local lootRanks = WBCDB.lootRanks

    for _, itemId in ipairs(allItemIds) do
        raidLootRanks[itemId] = {}

        local ordered = {}
        local n = 0
        for player, rank in pairs(lootRanks[itemId] or {}) do
            ordered[rank] = player
            n = n + 1
        end
        ordered.n = n

        local raidRank = 1
        for index, player in ipairs(ordered) do
            if raidMap[player] then
                raidLootRanks[itemId][player] = raidRank
                raidRank = raidRank + 1
            end
        end
    end

    recalculateBossLootRanks(raidLootRanks)
end

function LootDistributor:OnCommand(cmd)
    local linkEndIndex = string.find(cmd, '|r')
    local cmdValid = cmd ~= '' and linkEndIndex
    if cmdValid then
        local cmdMethod = cmd:sub(linkEndIndex + 2, -1)
        if cmdMethod then
            local lootMethod = lootMethodMap[cmdMethod]
            if lootMethod then
                if IsInRaid() and (UnitIsRaidOfficer('player') or UnitIsGroupLeader('player')) then
                    WBCoalition.Table:ClearPluses()
                    local msg = ' /roll'
                    if lootMethod == LOOT_METHOD_BUY then
                        msg = ' + in the raid chat or whisper if you want to buy with points'
                        isRoll = true
                    end
                    SendChatMessage(cmd:sub(1, linkEndIndex + 1) .. msg, 'RAID_WARNING')
                    if lootMethod == LOOT_METHOD_BUY then
                        isRoll = false
                        SendChatMessage(
                            'if you want to donate add a message e.g.: "+ donate to ' .. UnitName('player') .. '"',
                            'RAID')
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
        local startIndex, endIndex = string.find(message, "%[.+%]")
        local itemName = string.sub(message, startIndex + 1, endIndex - 1)

        if not isWBossLoot(itemName) then return end

        local zone = GetRealZoneText()
        local bossName = '<Unknown>'
        for _, name in pairs(WBCoalition.BOSS_NAMES) do
            if WBCCache.tracks[name] and WBCCache.tracks[name].zone == zone then bossName = name end
        end

        table.insert(WBCCache.lootLog, {
            zone = zone,
            item = itemName,
            player = player,
            boss = bossName,
            time = GetServerTime(),
            isRoll = isRoll
        })
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
