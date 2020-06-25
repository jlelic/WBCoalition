WBCTable = {}

local players = {}
local altMap = {}

local plusInTheChat = {}

local SORT = {
    ["WBCTablePlayersNameSort"] = "name",
    ["WBCTablePlayersPointsSort"] = "points",
    ["WBCTablePlayersInRaidAsSort"] = "inRaidAs",
    ["WBCTablePlayersAltsSort"] = "alts"
}

local playerDisplayOrder = {}
local sortBy = 'points'

PAGE_SIZE = 34
ROW_HEIGHT = 15

local initialized = false

local scrollView
local rows = {}
WBCRows = rows

local raid = {}
local raidMap = {}

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding

local function dec(data)
    data = string.gsub(data, '[^' .. b .. '=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

local function capitalize(word)
    if word == '' then return word end
    word = string.lower(word)
    return string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
end

local function createDropdown(node)
    local info = {}

    local name = node.playerName

    info = UIDropDownMenu_CreateInfo()
    info.isTitle = true
    info.text = name
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

    info = UIDropDownMenu_CreateInfo()
    info.isTitle = false
    info.text = 'Sync data'
    info.notCheckable = true
    info.func = function()
        WBCSync:SyncWith(name)
    end
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

    if raidMap[name] then
        if UnitIsRaidOfficer('player') or UnitIsGroupLeader('player') then
            for i = 1, #raidMap[name] do
                local raiderName = raidMap[name][i]
                info = UIDropDownMenu_CreateInfo()
                info.isTitle = false
                info.notCheckable = true
                info.text = 'Kick ' .. WBCoalition:GetClassColoredName(raiderName)
                info.func = function() UninviteUnit(raiderName) end
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
            end
        else
            info = UIDropDownMenu_CreateInfo()
            info.notCheckable = true
            info.disabled = true
            info.text = WBC_CLASS_COLOR_NONE .. "You can't kick people"
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
        end
    else
        if not IsInGroup() or UnitIsRaidOfficer('player') or UnitIsGroupLeader('player') then
            info = UIDropDownMenu_CreateInfo()
            info.notCheckable = true
            info.text = 'Invite to group'
            info.func = function() for i = 1, #players[name].alts do InviteUnit(players[name].alts[i]) end end
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
        else
            info = UIDropDownMenu_CreateInfo()
            info.notCheckable = true
            info.disabled = true
            info.text = WBC_CLASS_COLOR_NONE .. "You can't invite"
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
        end
    end

    info = UIDropDownMenu_CreateInfo()
    info.isTitle = false
    info.text = 'Cancel'
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
end

function getClassColoredName(name) return WBCoalition:GetClassColoredName(name) end

local function splitString(input, sep)
    if not input then return {} end
    local result = {}
    for str in string.gmatch(input, "([^" .. sep .. "]+)") do table.insert(result, str) end
    return result
end

function table.clone(original)
    local result = {}
    for k, v in pairs(original) do result[k] = v end
    return result
end

function table.keys(source)
    local result = {}
    for key, _ in pairs(source) do table.insert(result, key) end
    return result
end

function table.map(tbl, f)
    local t = {}
    for k, v in pairs(tbl) do t[k] = f(v) end
    return t
end

local function timeAgoToString(timestamp)
    if not timestamp then return 'never' end
    local timeAgo = GetServerTime() - timestamp
    if timeAgo < 60 then
        return "<1 minute"
    elseif timeAgo < 120 then
        return "1 minute"
    elseif timeAgo < 60 * 60 then
        return math.floor(timeAgo / 60) .. " minutes"
    elseif timeAgo < 60 * 60 * 2 then
        return "1 hour"
    elseif timeAgo < 60 * 60 * 48 then
        return math.floor(timeAgo / (60 * 60)) .. " hours"
    else
        return math.floor(timeAgo / (60 * 60 * 24)) .. " days"
    end
end

local sorters = {
    ["name"] = function(a, b) return WBCoalition:NormalizeString(a) < WBCoalition:NormalizeString(b) end,
    ["points"] = function(a, b)
        return (players[a] and players[a].points or -1) > (players[b] and players[b].points or -1)
    end,
    ["inRaidAs"] = function(a, b)
        return (raidMap[a] and WBCoalition:NormalizeString(raidMap[a][1]) or 'zzz') <
                   (raidMap[b] and WBCoalition:NormalizeString(raidMap[b][1]) or 'zzz')
    end,
    ["alts"] = function(a, b)
        return (players[a] and players[a].alts and players[a].alts[2] and
                   WBCoalition:NormalizeString(players[a].alts[2]) or 'zzz') <
                   (players[b] and players[b].alts and players[b].alts[2] and
                       WBCoalition:NormalizeString(players[b].alts[2]) or 'zzz')
    end
}

local function filterPlayer(player, filter)
    local normalizedFilter = WBCoalition:NormalizeString(filter)
    if string.find(WBCoalition:NormalizeString(player), normalizedFilter) ~= nil then return false end
    if players[player] and players[player].alts then
        for i = 2, #players[player].alts do
            local alt = players[player].alts[i]
            if string.find(WBCoalition:NormalizeString(alt), normalizedFilter) ~= nil then return false end
        end
    end
    return true
end


function WBCTable:Initialize()
    for i = 1, PAGE_SIZE do
        rowName = 'WBCTablePlayerHistoryFrameListFrameLine' .. tostring(i)
        row = {}
        row.line = _G[rowName]
        row.name = _G[rowName .. 'Name']
        row.points = _G[rowName .. 'Points']
        row.inRaidAs = _G[rowName .. 'InRaidAs']
        row.alts = _G[rowName .. 'Alts']
        table.insert(rows, row)
    end

    table.insert(UISpecialFrames, "WBCTableFrame")
    table.insert(UISpecialFrames, "WBCLoadFrame")

    WBCTable:UpdateRaidInfo()
    scrollView = WBCTableTabFrameTabContentFrameScrollFrame
end

function WBCTable:RaidOnlyToggled()
    if WBCTableInRaidCheckbox:GetChecked() then
        WBCTable:UpdateRaidInfo()
        WBCTableNotInRaidCheckbox:SetChecked(false)
    end
    WBCTable:Recalculate()
end

function WBCTable:RaidOnlyNotToggled()
    if WBCTableNotInRaidCheckbox:GetChecked() then
        WBCTable:UpdateRaidInfo()
        WBCTableInRaidCheckbox:SetChecked(false)
    end
    WBCTable:Recalculate()
end

function WBCTable:ClearPluses()
    plusInTheChat = {}
    WBCTable:Recalculate()
end

function WBCTable:ReportPluses()
    local candidateList = {}

    local playerList = table.keys(players)

    for i = 1, #raid do
        local raiderName = raid[i]
        local mainName = altMap[raiderName]
        if not mainName then table.insert(playerList, raiderName) end
    end

    for i = 1, #playerList do if plusInTheChat[playerList[i]] then table.insert(candidateList, playerList[i]) end end

    if #candidateList == 0 then
        WBCoalition:Log('|cffff0000No + in chat detected!')
        return
    end

    table.sort(candidateList, sorters['points'])

    SendChatMessage('Loot interest:', 'RAID')
    for i = 1, #candidateList do
        local candidate = candidateList[i]
        local plus = plusInTheChat[candidate]

        local msg
        if WBCDB.players[candidate] then
            local points = WBCDB.players[candidate].points
            msg = '  ' .. i .. '. ' .. points .. 'p ' .. plus.sender
            if plus.sender ~= candidate then msg = msg .. ' (' .. candidate .. ')' end
        else
            msg = '  ' .. i .. '. {cross} ' .. plus.sender .. ' (not found in the sheet)' 
        end
        msg = msg .. ' ' .. plusInTheChat[candidate].msg
        SendChatMessage(msg, 'RAID')
    end
end

function WBCTable:Filter() WBCTable:Recalculate() end

function WBCTable:Recalculate()
    if WBCDB.lastUpdate.time then
        WBCTableFrameLastUpdateText:SetText(WBC_CLASS_COLOR_NONE .. 'Data from ' ..
                                                timeAgoToString(WBCDB.lastUpdate.time) .. ' ago, source: ' ..
                                                (WBCDB.lastUpdate.source or '<Unkown>'))
    else
        WBCTableFrameLastUpdateText:SetText()
    end

    altMap = WBCDB.altMap
    players = WBCDB.players

    playerList = table.keys(players)

    if not WBCTableNotInRaidCheckbox:GetChecked() then
        for i = 1, #raid do
            local raiderName = raid[i]
            local mainName = altMap[raiderName]
            if not mainName then table.insert(playerList, raiderName) end
        end
    end

    if WBCTableInRaidCheckbox:GetChecked() then
        playerList = {}
        local alreadyCounted = {}
        for i = 1, #raid do
            local raiderName = raid[i]
            local mainName = altMap[raiderName]
            if mainName == nil then
                table.insert(playerList, raiderName)
            elseif alreadyCounted[mainName] ~= true then
                alreadyCounted[mainName] = true
                table.insert(playerList, mainName)
            end
        end
    elseif WBCTableNotInRaidCheckbox:GetChecked() then
        local isInRaid = {}
        for i = 1, #raid do
            local raiderName = raid[i]
            local mainName = altMap[raiderName]
            if mainName then isInRaid[mainName] = true end
        end
        local newPlayerList = {}
        for i = 1, #playerList do
            if isInRaid[playerList[i]] == nil then table.insert(newPlayerList, playerList[i]) end
        end
        playerList = newPlayerList
    end

    if WBCTableShowInterestedCheckbox:GetChecked() then
        local newPlayerList = {}
        for i = 1, #playerList do
            if plusInTheChat[playerList[i]] then table.insert(newPlayerList, playerList[i]) end
        end
        playerList = newPlayerList
    end

    local filter = WBCTableFilterBox:GetText()

    if filter == '' then
        playerDisplayOrder = table.clone(playerList)
    else
        playerDisplayOrder = {}
        for i = 1, #playerList do
            if not filterPlayer(playerList[i], filter) then table.insert(playerDisplayOrder, playerList[i]) end
        end
    end

    table.sort(playerDisplayOrder, sorters[sortBy])
    WBCTable:Refresh()
end

function WBCTable:Refresh()
    FauxScrollFrame_Update(scrollView, #playerDisplayOrder, PAGE_SIZE, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollView)
    local serverTime = GetServerTime()
    for i = 1, PAGE_SIZE do
        local playerName = playerDisplayOrder[offset + i]
        rows[i].name:SetText(WBCoalition:GetClassColoredName(playerName))

        if playerName and players[playerName] then
            rows[i].points:SetText(players[playerName].points)
        else
            rows[i].points:SetText()
        end

        if raidMap[playerName] == nil then
            rows[i].inRaidAs:SetText()
        else
            rows[i].inRaidAs:SetText(table.concat(table.map(raidMap[playerName], getClassColoredName),
                                                  WBC_CLASS_COLOR_NONE .. ', '))
        end

        if not playerName or not players[playerName] or not players[playerName].alts then
            rows[i].alts:SetText()
        else
            local justAlts = {}
            local playerAlts = players[playerName].alts
            for j = 2, #playerAlts do table.insert(justAlts, playerAlts[j]) end
            rows[i].alts:SetText(table.concat(table.map(justAlts, getClassColoredName), WBC_CLASS_COLOR_NONE .. ', '))
        end

        if not playerName or not plusInTheChat[playerName] then
            rows[i].line:GetNormalTexture():SetColorTexture(0, 0, 0, 0)
        else
            rows[i].line:GetNormalTexture():SetColorTexture(0, 1, 0, 0.1)
        end

        rows[i].line.playerName = playerName
    end
end

function WBCTable:SetSortColumn(buttonName)
    sortBy = SORT[buttonName]
    WBCTable:Recalculate()
end

function WBCTable:Show()
    WBCTable:Recalculate()
    WBCTableFrame:Show()
end

function WBCTable:ShowDropDown(node, button)
    if button ~= "RightButton" or not node.playerName then return end
    GameTooltip:Hide()
    local cursor = GetCursorPosition() / UIParent:GetEffectiveScale()
    local center = node:GetLeft() + (node:GetWidth() / 2)
    WBCTableDropDownMenu.playerName = node.playerName
    UIDropDownMenu_Initialize(WBCTableDropDownMenu, createDropdown, "MENU")
    UIDropDownMenu_SetAnchor(WBCTableDropDownMenu, cursor - center, 0, "TOPRIGHT", node, "TOP")
    CloseDropDownMenus(1)
    ToggleDropDownMenu(1, nil, WBCTableDropDownMenu)
end

function WBCTable:ParseInput()
    local decoded = dec(WBCLoadEditBox:GetText())
    if string.sub(decoded, 1, 9) == 'Coalition' then
        WBCLoadFrame:Hide()

        altMap = {}
        players = {}

        local lines = splitString(decoded, '\n\r')
        local lastUpdate = math.floor(tonumber(splitString(lines[1], ',')[2]))
        for i = 2, #lines do
            local line = splitString(lines[i], ',')
            local name = line[1]
            local playerPoints = math.floor(tonumber(line[2]) + 0.5)
            local altListRaw = splitString(line[3], ';')
            local altList = {}
            local altAdded = {}
            for _,alt in pairs(altListRaw) do
                local len = str
                if alt:sub(1, 1) ~= '(' and alt:sub(-1,-1)~= ')' then
                    local altName = capitalize(alt)
                    if not altAdded[altName] then
                       table.insert(altList, altName)
                       altAdded[altName] = true 
                    end
                end
            end

            players[name] = {alts = {}, points = playerPoints}

            altMap[name] = name
            for j = 1, #altList do
                local altName = altList[j]
                altMap[altName] = name
                table.insert(players[name].alts, altName)
            end
            table.insert(players[name].alts, 1, name)
        end

        playerDisplayOrder = table.clone(players)
        WBCLoadEditBox:SetText('')
        WBCoalition:Log("Data loaded :)")

        WBCDB.players = players
        WBCDB.lastUpdate = {time = lastUpdate, source = '<Sheet>'}
        WBCDB.altMap = altMap
        WBCTable:Recalculate()
        WBCSync:OnNewDataLoaded()
    end
end

function WBCTable:ShowInterestedToggled() WBCTable:Recalculate() end

function WBCTable:UpdateRaidInfo()
    raid = {}
    raidMap = {}
    altMap = WBCDB.altMap
    if not UnitInRaid('player') then return end
    for i = 1, 40 do
        local raiderName = GetRaidRosterInfo(i)
        if raiderName ~= nil then
            table.insert(raid, raiderName)
            local mainName = altMap[raiderName]
            if mainName ~= nil then
                if raidMap[mainName] == nil then raidMap[mainName] = {} end
                table.insert(raidMap[mainName], raiderName)
            else
                raidMap[raiderName] = {raiderName}
            end
            WBCoalition:NormalizeString(raiderName)
        end
    end
end

local function processEvent(event, type, ...)
    if type == 'VARIABLES_LOADED' then
        WBCDB = WBCDB or {}
        WBCDB.players = WBCDB.players or {}
        WBCDB.lastUpdate = WBCDB.lastUpdate or {time = nil, source = nil}
        WBCDB.altMap = WBCDB.altMap or {}

        WBCCache = WBCCache or {}
        WBCCache.classes = WBCCache.classes or {}
        WBCCache.tracks = WBCCache.tracks or {}
        WBCCache.lootLog = WBCCache.lootLog or {}
        
        WBCTable:Initialize()
        WBCoalition:Initialize()
        WBCSync:Initialize()
        WBCTable:UpdateRaidInfo()
        WBCTable:Recalculate()
    elseif type == 'CHAT_MSG_RAID' or type == 'CHAT_MSG_RAID_LEADER' or type == 'CHAT_MSG_PARTY' or type ==
        'CHAT_MSG_PARTY_LEADER' or type == 'CHAT_MSG_WHISPER' then
        local msg, sender = ...
        local name = splitString(sender, '-')[1]
        if string.sub(msg, 1, 1) == '+' then
            local senderName = splitString(sender, '-')[1]
            local mainName = altMap[name]
            if mainName then name = mainName end
            plusInTheChat[name] = {msg = msg, sender = senderName}
            WBCTable:Recalculate()
        end
        if type == 'CHAT_MSG_WHISPER' then WBCInviteHelper:OnWhisper(name, msg) end
    elseif type == 'GROUP_ROSTER_UPDATE' then
        WBCTable:UpdateRaidInfo()
        WBCTable:Recalculate()
        WBCSync:OnRaidStatusChange()
    elseif type == 'WHO_LIST_UPDATE' then
        WBCScoutScanner:OnWhoResult()
    elseif type == 'LOOT_OPENED' then
        WBCLootDistributor:OnLootOpened()
    elseif type == 'CHAT_MSG_LOOT' then
        WBCLootDistributor:OnLootMessage(...)
    elseif type == 'PLAYER_TARGET_CHANGED' then
        WBCTracker:OnTargetChanged()
    end
end

function WBCTable:Start()
    if WBCTableFrame == nil then return end
    WBCTableFrame:RegisterEvent('VARIABLES_LOADED')
    WBCTableFrame:RegisterEvent('CHAT_MSG_RAID')
    WBCTableFrame:RegisterEvent('CHAT_MSG_RAID_LEADER')
    WBCTableFrame:RegisterEvent('CHAT_MSG_PARTY')
    WBCTableFrame:RegisterEvent('CHAT_MSG_PARTY_LEADER')
    WBCTableFrame:RegisterEvent('CHAT_MSG_WHISPER')
    WBCTableFrame:RegisterEvent('GROUP_ROSTER_UPDATE')
    WBCTableFrame:RegisterEvent('WHO_LIST_UPDATE')
    WBCTableFrame:RegisterEvent('LOOT_OPENED')
    WBCTableFrame:RegisterEvent('PLAYER_TARGET_CHANGED')
    WBCTableFrame:RegisterEvent('CHAT_MSG_LOOT')
    WBCTableFrame:SetScript('OnEvent', processEvent)
end

WBCTable:Start()
