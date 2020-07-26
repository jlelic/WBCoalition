WBCoalition.Sync = {}
local Sync = WBCoalition.Sync

local WBC_PREFIX = 'WBCoa'
local WBC_DATA_PREFIX = 'WBCData'

local MSG_OFFER_DATA = 'OFFER_DATA'
local MSG_REQUEST_DATA = 'REQUEST_DATA'
local MSG_FORCE_SYNC_STATE = 'FSYNC'

local aceComm
local deflate

local requestedUpdateTime

local wasInRaid = false

local FORCE_SYNC_STATE = {
    none = 'NONE',
    offer = 'OFFER',
    counteroffer = 'COUNTEROFFER',
    equal = 'EQUAL',
    received = 'RECEIVED'
}

local FORCE_SYNC_COLOR_OK = '|cff55ff55'

local forceSyncStates = {}

local function getDetailedSenderName(sender)
    local mainName = WBCDB.altMap[sender]
    local senderDetailed = sender
    if not mainName then mainName = sender end
    if sender ~= mainName then senderDetailed = senderDetailed .. ' (' .. mainName .. ')' end
    return senderDetailed, mainName
end

local function sendData(channel, target, fsyncState)
    if not WBCDB.lastUpdate.time then return end

    fsyncState = fsyncState or FORCE_SYNC_STATE.none

    local header = WBCDB.lastUpdate.time .. ',' .. fsyncState

    local data = ''
    for name, info in pairs(WBCDB.players) do
        local newLine = ';' .. info.points .. '^' .. table.concat(info.alts, ',') .. '^'  .. table.concat(info.lootInterest, ',')
        data = data .. newLine
    end

    local pointsData = header .. ';' .. data

    local compressedMsg = deflate:EncodeForWoWAddonChannel(deflate:CompressDeflate(pointsData))

    aceComm:SendCommMessage(WBC_DATA_PREFIX, compressedMsg, channel, target, 'BULK')
end

local function sendOffer(channel, target, fsyncState)
    fsyncState = fsyncState or FORCE_SYNC_STATE.none
    local msg = MSG_OFFER_DATA .. ',' .. (WBCDB.lastUpdate.time or 0) .. ',' .. fsyncState
    aceComm:SendCommMessage(WBC_PREFIX, msg, channel, target, 'NORMAL')
end

local function sendRequest(channel, target, fsyncState)
    fsyncState = fsyncState or FORCE_SYNC_STATE.none
    local msg = MSG_REQUEST_DATA .. ',' .. (WBCDB.lastUpdate.time or 0) .. ',' .. fsyncState
    aceComm:SendCommMessage(WBC_PREFIX, msg, channel, target, 'NORMAL')
end

local function sendFSyncStateUpdate(channel, target, fsyncState)
    fsyncState = fsyncState or FORCE_SYNC_STATE.none
    local msg = MSG_FORCE_SYNC_STATE .. ',' .. (WBCDB.lastUpdate.time or 0) .. ',' .. fsyncState
    aceComm:SendCommMessage(WBC_PREFIX, msg, channel, target, 'NORMAL')
end

local function onCommReceived(prefix, msg, channel, sender)
    local lines = {strsplit(';', msg)}
    local msgType, lastUpdateStr, fsyncState = strsplit(',', lines[1])
    local lastUpdate = tonumber(lastUpdateStr)
    local myLastUpdate = WBCDB.lastUpdate.time or 0
    local senderDetailed, mainName = getDetailedSenderName(sender)

    if msgType == MSG_OFFER_DATA then
        if lastUpdate > myLastUpdate then
            if not requestedUpdateTime or requestedUpdateTime < lastUpdate then
                requestedUpdateTime = lastUpdate

                local delay = 3 * random()
                local replyFSyncState = FORCE_SYNC_STATE.none

                if fsyncState == FORCE_SYNC_STATE.offer then
                    delay = 0.1
                    WBCoalition:Log(senderDetailed .. ' initiated sync, requesting more recent version from them...')
                elseif fsyncState == FORCE_SYNC_STATE.counteroffer then
                    delay = 0.1
                    WBCoalition:Log('Requesting more recent data from ' .. senderDetailed .. '...')
                end

                C_Timer.After(delay, function()
                    sendRequest('WHISPER', sender, fsyncState)
                    C_Timer.After(10, function() requestedUpdateTime = nil end)
                end)
            end

        elseif lastUpdate < myLastUpdate then
            newFSyncState = FORCE_SYNC_STATE.none
            if fsyncState == FORCE_SYNC_STATE.offer then
                WBCoalition:Log(senderDetailed .. ' requested sync, they have older data')
                newFSyncState = FORCE_SYNC_STATE.counteroffer
            end
            sendOffer('WHISPER', sender, newFSyncState)

        elseif fsyncState == FORCE_SYNC_STATE.offer then
            WBCoalition:Log(FORCE_SYNC_COLOR_OK .. senderDetailed ..
                                ' initiated sync but you already have the same version')
            sendFSyncStateUpdate('WHISPER', sender, FORCE_SYNC_STATE.equal)
        end
    elseif msgType == MSG_REQUEST_DATA then
        if fsyncState ~= FORCE_SYNC_STATE.none then
            WBCoalition:Log('Sending newer version to ' .. senderDetailed .. '...')
        end
        sendData('WHISPER', sender, fsyncState)
    elseif msgType == MSG_FORCE_SYNC_STATE then
        if fsyncState == FORCE_SYNC_STATE.equal then
            WBCoalition:Log(FORCE_SYNC_COLOR_OK .. 'You have the same version as ' .. senderDetailed)
            forceSyncStates[mainName] = nil
        elseif fsyncState == FORCE_SYNC_STATE.received then
            WBCoalition:Log(FORCE_SYNC_COLOR_OK .. senderDetailed .. ' had their data sucessfully updated')
            forceSyncStates[mainName] = nil
        end
    end
end

local function onDataReceived(prefix, compressedMsg, channel, sender)
    local msg = deflate:DecompressDeflate(deflate:DecodeForWoWAddonChannel(compressedMsg))
    local senderDetailed, mainName = getDetailedSenderName(sender)

    local lines = {strsplit(';', msg)}
    local lastUpdateStr, fsyncState = strsplit(',', lines[1])
    local lastUpdate = tonumber(lastUpdateStr)

    if lastUpdate < (WBCDB.lastUpdate.time or 0) then sendOffer('WHISPER', sender) end
    local newPlayers = {}
    local newAltMap = {}
    for i = 2, #lines do
        if strlen(lines[i]) > 0 then
            local points, altListJoined, lootInterestJoined = strsplit('^', lines[i])

            local altList = {strsplit(',', altListJoined)}
            local name = altList[1]
            
            local lootInterestStr = {strsplit(',', lootInterestJoined)}
            local lootInterest = {}
            for _,itemIdStr in ipairs(lootInterestStr) do
                table.insert(lootInterest, tonumber(itemIdStr))
            end


            newPlayers[name] = {alts = altList, points = tonumber(points), lootInterest = lootInterest}
            for j = 1, #altList do newAltMap[altList[j]] = name end
        end
    end

    WBCDB.players = newPlayers
    WBCDB.altMap = newAltMap
    WBCDB.lastUpdate.time = lastUpdate
    WBCDB.lastUpdate.source = sender
    WBCoalition.LootDistributor:RecalculateLootRanks()
    WBCoalition.Table:Recalculate()
    WBCoalition.Table:UpdateRaidInfo()

    if fsyncState == FORCE_SYNC_STATE.offer then
        WBCoalition:Log(FORCE_SYNC_COLOR_OK .. 'Received update from ' .. senderDetailed)
        sendFSyncStateUpdate('WHISPER', sender, FORCE_SYNC_STATE.received)
    elseif fsyncState == FORCE_SYNC_STATE.counteroffer then
        WBCoalition:Log(FORCE_SYNC_COLOR_OK .. 'Received update from ' .. senderDetailed)
        forceSyncStates[mainName] = nil
    else
        WBCoalition:Log('Received update from ' .. senderDetailed)
    end

    C_Timer.After(2 + 5 * random(), function() sendOffer('RAID') end)
    if IsInGuild() then C_Timer.After(5 + 10 * random(), function() sendOffer('GUILD') end) end

end

function Sync:Initialize()
    aceComm = LibStub:GetLibrary("AceComm-3.0")
    aceComm:RegisterComm(WBC_PREFIX, onCommReceived)
    aceComm:RegisterComm(WBC_DATA_PREFIX, onDataReceived)

    deflate = LibStub:GetLibrary("LibDeflate")

    C_Timer.After(5, function() Sync:OnRaidStatusChange() end)
    if IsInGuild() then C_Timer.After(15, function() sendOffer('GUILD') end) end
end

function Sync:OnRaidStatusChange()
    if not wasInRaid and IsInRaid() then sendOffer('RAID') end
    wasInRaid = IsInRaid()
end

function Sync:OnNewDataLoaded()
    if IsInRaid() then sendOffer('RAID') end
    if IsInGuild() then C_Timer.After(10, function() sendOffer('GUILD') end) end
end

function Sync:SyncWith(mainName)
    if forceSyncStates[mainName] then
        WBCoalition:LogError('Syncing with ' .. mainName .. ' already in progress')
        return
    end
    WBCoalition:Log('Syncing with ' .. mainName)
    forceSyncStates[mainName] = {state = FORCE_SYNC_STATE.offer}
    if WBCDB.players[mainName] then
        for _, altName in pairs(WBCDB.players[mainName].alts) do
            sendOffer('WHISPER', altName, FORCE_SYNC_STATE.offer)
        end
    else
        sendOffer('WHISPER', mainName, FORCE_SYNC_STATE.offer)
    end
    C_Timer.After(8, function()
        if forceSyncStates[mainName] then
            WBCoalition:LogError('Attempt to sync with ' .. mainName .. ' failed')
            forceSyncStates[mainName] = nil
        end
    end)
end
