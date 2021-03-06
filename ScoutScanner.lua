WBCoalition.ScoutScanner = {}
local Scanner = WBCoalition.ScoutScanner

local competitors = {
    {'Praxis', 'Undying Legacy', 'A Bards Tale', 'Neighbourhood'},
    {'Redrum Inc', 'RR Inc', 'Solid', 'CORE', 'Ember', 'Close to Insanity', 'Scarlet Crusade'}
}

local isScanning = false

local ZONES = {'Azshara', 'Blasted Lands', 'Ashenvale', 'Feralas', 'Duskwood', 'The Hinterlands'}

local results = {}
local zoneIndex = 0
local gotResultsFor = 0
local try = 1

local DIALOG_CONTINUE_SCANNING = 'DIALOG_WBC_CONTINUE_SCANNING'

local function isScout(name)
    if WBCDB.altMap[name] then
        return true
    end
    return false
end

local function isCompetitor(name,guild)
    if name == 'Kimeera' then return 1 end
    for i=1,#competitors do
        for j=1,#competitors[i] do
            if competitors[i][j] == guild then
                return i
            end
        end
    end
    return 0
end

local function reportPlayerInfo(index, playerInfo)
    _, _, _, classColor = GetClassColor(playerInfo.gameClass)
    WBCCache.classes[playerInfo.name] = playerInfo.gameClass
    local levelColor = ' |cffffff00'
    if playerInfo.level < 60 then
        levelColor = ' |cff33aa33'
    end
    WBCoalition:Log('        ' .. index .. '. ' .. ' |c' .. classColor .. playerInfo.name  .. levelColor.. playerInfo.level .. '|cffffffff, ' .. playerInfo.guild)
end

local function reportResults()
    WBCoalition:Log('Scout Scan Results: ')
    for i=1,#results do
        local zoneInfo = results[i]
        WBCoalition:Log('|cffffffcc' .. zoneInfo.name)

        if #zoneInfo.scouts > 0 then
            WBCoalition:Log('   Coalition:')
            for j=1,#zoneInfo.scouts do
                local scout = zoneInfo.scouts[j]
                reportPlayerInfo(j, scout)
            end
        else
            WBCoalition:Log('   |cffff0000We are missing scouts in ' .. zoneInfo.name .. '!')
        end

        for c=1,#competitors do
            local competitorLeader = competitors[c][1]
            if #zoneInfo.competitors[c] > 0 then
                WBCoalition:Log('   ' .. competitorLeader ..':')
                for j=1,#zoneInfo.competitors[c] do
                    local scout = zoneInfo.competitors[c][j]
                    reportPlayerInfo(j, scout)
                end
            else
                WBCoalition:Log('   |cffff0000' .. competitorLeader .. ' is missing scouts in ' .. zoneInfo.name .. '!')
            end
        end
    end
end

local function saveWhoResults()
    local x, total = C_FriendList.GetNumWhoResults()
    local zoneInfo = {name = ZONES[zoneIndex], scouts={}, competitors={}, total = total}
    for i=1,#competitors do
        table.insert(zoneInfo.competitors, {})
    end
    for i=1,total do
        local info = C_FriendList.GetWhoInfo(i)
        local name, guild, level, race, class, _, gameClass, gender = info.fullName, info.fullGuildName, info.level, info.raceStr, info.classStr, info.area, info.filename, info.gender
        local playerInfo = {
            name = name,
            guild = guild,
            level = level,
            race = race,
            class = class,
            gameClass = gameClass,
            gender = gender
        }
        if isScout(name) then
            table.insert(zoneInfo.scouts, playerInfo)
        end
        local competitor = isCompetitor(name, guild)
        if competitor > 0 then
            table.insert(zoneInfo.competitors[competitor], playerInfo)
        end
    end
    table.insert(results, zoneInfo)
end

local function scanNextZone()
    StaticPopup_Hide(DIALOG_CONTINUE_SCANNING)

    if zoneIndex > #ZONES then return end

    local zone = ZONES[zoneIndex]
    local msg = zone
    if try > 1 then
        msg = msg .. ' (attempt ' .. try .. ')'
    end
    msg = msg .. '\n' .. zoneIndex .. '/' .. #ZONES

    StaticPopup_Show(DIALOG_CONTINUE_SCANNING, msg)
end

StaticPopupDialogs[DIALOG_CONTINUE_SCANNING] = {
    text = '%s',
    button1 = 'Scan',
    button2 = 'Stop',
    OnAccept = function(self, data)
        local zone = ZONES[zoneIndex]
        C_FriendList.SetWhoToUi(true)
        FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
        C_FriendList.SendWho(zone)
        try = try + 1
        WBCoalition:Log('Scanning ' .. zone .. '...')
        C_Timer.After(3, function()
            if gotResultsFor < zoneIndex then
                scanNextZone()
            end
        end)
    end,
    OnCancel = function()
        isScanning = false
        if zoneIndex > 1 then
            reportResults()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

function Scanner:OnWhoResult()
    if not isScanning then return end
    FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
    saveWhoResults()
    local zone = ZONES[zoneIndex]
    try = 1
    gotResultsFor = zoneIndex
    zoneIndex = zoneIndex + 1
    if zoneIndex > #ZONES then
        isScanning = false
        reportResults()
    end
    scanNextZone()
end

function Scanner:Scan()
    results = {}
    isScanning = true
    zoneIndex = 1
    gotResultsFor = 0
    scanNextZone()
end
