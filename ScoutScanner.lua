WBCoalition.ScoutScanner = {}

local Scanner = WBCoalition.ScoutScanner

local ENEMIES = {{'Praxis', 'Legacy', 'A Bards Tale'}}

local WBC

local Scanner = WBCoalition.ScoutScanner

local isScanning = false

local ZONES = {'Azshara', 'Blasted Lands', 'Ashenvale', 'Feralas', 'Duskwood', 'The Hinterlands'}

local results = {}
local zoneIndex = 0
local gotResultsFor = 0
local try = 0

local DIALOG_CONTINUE_SCANNING = 'DIALOG_WBC_CONTINUE_SCANNING'

local function isScout(name)
    if WBCDB.altMap[name] then
        return true
    end
    return false
end

local function isEnemyCoalition(name,guild)
    if name == 'Kimeera' then return 1 end
    for i=1,#ENEMIES do
        for j=1,#ENEMIES[i] do
            if ENEMIES[i][j] == guild then
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
    WBC:Log('        ' .. index .. '. ' .. ' |c' .. classColor .. playerInfo.name  .. levelColor.. playerInfo.level .. '|cffffffff, ' .. playerInfo.guild)
end

local function reportResults()
    WBC:Log('-- RESULTS --')
    for i=1,#results do
        local zoneInfo = results[i]
        WBC:Log('|cffffffcc' .. zoneInfo.name)
        WBC:Log('   Coalition:')
        for j=1,#zoneInfo.scouts do
            local scout = zoneInfo.scouts[j]
            reportPlayerInfo(j, scout)
        end
        if #zoneInfo.scouts == 0 then
            WBC:Log('   |cffff0000We are missing scouts in ' .. zoneInfo.name .. '!!')
        end
        WBC:Log('   Praxis Coalition:')
        for j=1,#zoneInfo.enemies[1] do
            local scout = zoneInfo.enemies[1][j]
            reportPlayerInfo(j, scout)
        end
        if #zoneInfo.enemies[1] == 0 then
            WBC:Log('   |cffff0000Praxis is missing scouts in ' .. zoneInfo.name .. '!!')
        end
    end
end

local function saveWhoResults()
    local x, total = C_FriendList.GetNumWhoResults()
    local zoneInfo = {name = ZONES[zoneIndex], scouts={}, enemies={}, total = total}
    for i=1,#ENEMIES do
        table.insert(zoneInfo.enemies, {})
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
        local enemyCoalition = isEnemyCoalition(name, guild)
        if enemyCoalition > 0 then
            table.insert(zoneInfo.enemies[enemyCoalition], playerInfo)
        end
    end
    table.insert(results, zoneInfo)
end

local function scanNextZone()
    StaticPopup_Hide(DIALOG_CONTINUE_SCANNING)

    if zoneIndex > #ZONES then return end

    local zone = ZONES[zoneIndex]
    local msg = ''
    if try > 1 then
        msg = 'Scan failed\n'
    end
    msg = msg .. 'Scanning ' .. zone
    msg = msg .. '\n' .. zoneIndex .. '/' .. #ZONES

    StaticPopup_Show(DIALOG_CONTINUE_SCANNING, msg)
end

StaticPopupDialogs[DIALOG_CONTINUE_SCANNING] = {
    text = '%s',
    button1 = 'Continue scanning',
    button2 = 'Cancel',
    OnAccept = function(self, data)
        local currentIndex = zoneIndex
        local zone = ZONES[zoneIndex]
        C_FriendList.SendWho(zone)
        try = try + 1
        WBC:Log('Scanning ' .. zone .. '...')
        C_Timer.After(3, function()
            if gotResultsFor < zoneIndex then
                scanNextZone()
            end
        end)
    end,
    OnCancel = function() isScanning = false end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

function Scanner:OnWhoResult()
    if not isScanning then return end
    saveWhoResults()
    local zone = ZONES[zoneIndex]
    try = 0
    gotResultsFor = zoneIndex
    zoneIndex = zoneIndex + 1
    if zoneIndex > #ZONES then
        WBC:Log('Scan completed')
        reportResults()
    end
    scanNextZone()
end

function Scanner:Scan()
    WBC = WBCoalition
    WBC:Log('Scan initiated')
    results = {}
    isScanning = true
    zoneIndex = 1
    gotResultsFor = 0
    scanNextZone()
end
