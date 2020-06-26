SLASH_WBC1 = "/wbc"

WBCIcon = {}
WBCDB = {players = {}, altMap = {}, lastUpdate = {}}
WBCCache = {classes = {}, tracks = {}, loogLot = {}}
WBCTemp = {normalizedStrings = {}}

WBC_CLASS_COLOR_NONE = '|cffc2b5b5'

local greenDragonColor = '|cff99ff99'

WBC_BOSS_DATA = {
    ['Lord Kazzak'] = {
        loot = {18546, 17111, 18204, 19135, 18544, 19134, 19133, 18543, 17112, 17113, 18665},
        color = '|cffaa99ff'
    },
    ['Azuregos'] = {
        loot = {19132, 18208, 18541, 18547, 18545, 19131, 19130, 17070, 18202, 18542, 18704},
        color = '|cff58d0e8'
    },
    ['Lethon'] = {
        loot = {
            20628, 20626, 20630, 20625, 20627, 20629,
            20579, 20615, 20616, 20618, 20617, 20619, 20582, 20644, 20580, 20581
        },
        color = greenDragonColor
    }
}

WBC_BOSS_NAMES = {}
for bossName,_ in pairs(WBC_BOSS_DATA) do
    table.insert(WBC_BOSS_NAMES, bossName)
end

WBCoalition = {}

local tableAccents = {}
tableAccents["å"] = "a"
tableAccents["à"] = "a"
tableAccents["á"] = "a"
tableAccents["â"] = "a"
tableAccents["ã"] = "a"
tableAccents["ä"] = "a"
tableAccents["ç"] = "c"
tableAccents["è"] = "e"
tableAccents["é"] = "e"
tableAccents["ê"] = "e"
tableAccents["ë"] = "e"
tableAccents["ì"] = "i"
tableAccents["í"] = "i"
tableAccents["î"] = "i"
tableAccents["ï"] = "i"
tableAccents["ñ"] = "n"
tableAccents["ò"] = "o"
tableAccents["ó"] = "o"
tableAccents["ô"] = "o"
tableAccents["õ"] = "o"
tableAccents["ö"] = "o"
tableAccents["ø"] = "o"
tableAccents["ù"] = "u"
tableAccents["ú"] = "u"
tableAccents["û"] = "u"
tableAccents["ü"] = "u"
tableAccents["ý"] = "y"
tableAccents["ÿ"] = "y"

local function createPlayerDropdown(node)
    local info = {}

    info = UIDropDownMenu_CreateInfo()
    info.isTitle = true
    info.text = 'WB Coalition'
    info.notCheckable = true
    info.disabled = true
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

    info = UIDropDownMenu_CreateInfo()
    info.isTitle = false
    info.text = 'Show sheet'
    info.notCheckable = true
    info.func = function() WBCoalition.Table:Show() end
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

    info = UIDropDownMenu_CreateInfo()
    info.isTitle = false
    info.text = 'Show loot log'
    info.notCheckable = true
    info.func = function() WBCLootLog:Show() end
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

    info = UIDropDownMenu_CreateInfo()
    info.isTitle = false
    info.text = 'Clear data'
    info.notCheckable = true
    info.func = function()
        WBCDB = {players = {}, altMap = {}, lastUpdate = {}}
        -- WBCCache = {classes = {}}
        WBCTemp = {normalizedStrings = {}}
        WBCoalition.Table:Recalculate()
        WBCoalition:Log('Data cleared!')
    end
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

    info = UIDropDownMenu_CreateInfo()
    info.isTitle = false
    info.text = 'Cancel'
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
end

function WBCoalition:Initialize()
    local data = {
        type = "data source",
        icon = "Interface\\Icons\\INV_misc_head_dragon_green",
        OnClick = function(icon, button)
            if button == 'LeftButton' then
                if WBCTableFrame:IsShown() then
                    WBCTableFrame:Hide()
                else
                    WBCoalition.Table:Show()
                end
            elseif button == 'RightButton' then
                GameTooltip:Hide()
                UIDropDownMenu_Initialize(WBCTableDropDownMenu, createPlayerDropdown, "MENU")
                UIDropDownMenu_SetAnchor(WBCTableDropDownMenu, 0, 0, "TOPRIGHT", icon, "BOTTOMLEFT")
                CloseDropDownMenus(1)
                ToggleDropDownMenu(1, nil, WBCTableDropDownMenu)
            else
                WBCoalition.ScoutScanner:Scan()
            end
        end,
        OnEnter = function(self, button)
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:SetPoint("TOPRIGHT", self, "BOTTOMLEFT")
            GameTooltip:AddLine("World Boss Coalition");
            GameTooltip:Show()
        end,
        OnLeave = function(self, button) GameTooltip:Hide() end
    }
    local iconLDB = LibStub("LibDataBroker-1.1"):NewDataObject("WBCIcon", data)
    local icon = LibStub("LibDBIcon-1.0")
    self.db = LibStub("AceDB-3.0"):New("WBCIcon", {profile = {minimap = {hide = false}}})
    icon:Register("WBCIcon", iconLDB, self.db.profile.minimap)

    -- cache loot item info
    for boss,data in pairs(WBC_BOSS_DATA) do
        for _,itemId in pairs(data.loot) do
            GetItemInfo(itemId)
        end
    end
end

function WBCoalition:NormalizeString(input)
    local str = string.lower(input)
    local normalizedString = ''

    if WBCTemp.normalizedStrings[input] then return WBCTemp.normalizedStrings[input] end

    for strChar in string.gmatch(str, "([%z\1-\127\194-\244][\128-\191]*)") do
        if tableAccents[strChar] ~= nil then
            normalizedString = normalizedString .. tableAccents[strChar]
        else
            normalizedString = normalizedString .. strChar
        end
    end

    WBCTemp.normalizedStrings[input] = normalizedString

    return normalizedString
end

function WBCoalition:GetClassColoredName(name)
    if name == nil then return nil end

    local playerClass = WBCCache.classes[name]
    local classColor = WBC_CLASS_COLOR_NONE
    if playerClass == nil then
        _, playerClass = UnitClass(name)
        if playerClass == nil then return WBC_CLASS_COLOR_NONE .. name end
        _, _, _, classColor = GetClassColor(playerClass)
        WBCCache.classes[name] = playerClass
    else
        _, _, _, classColor = GetClassColor(playerClass)
    end
    return '|c' .. classColor .. name
end

function WBCoalition:Debug(msg) if WBCCache.debug then print("|cff55cc77[|cffccffddWBC|cff55cc77]|r " .. msg) end end

function WBCoalition:Log(msg) print("|cff55cc77[|cffccffddWBC|cff55cc77]|r " .. msg) end

function WBCoalition:LogError(msg) WBCoalition:Log('|cffff0000' .. msg) end

function SlashCmdList.WBC(cmd) WBCoalition.LootDistributor:OnCommand(cmd) end

local function processEvent(event, type, ...)
    print('EVENT')
    if type == 'VARIABLES_LOADED' then
        WBCDB = WBCDB or {}
        WBCDB.players = WBCDB.players or {}
        WBCDB.lastUpdate = WBCDB.lastUpdate or {time = nil, source = nil}
        WBCDB.altMap = WBCDB.altMap or {}

        WBCCache = WBCCache or {}
        WBCCache.classes = WBCCache.classes or {}
        WBCCache.tracks = WBCCache.tracks or {}
        WBCCache.lootLog = WBCCache.lootLog or {}
        
        WBCoalition.Table:Initialize()
        WBCoalition:Initialize()
        WBCoalition.Sync:Initialize()
        WBCoalition.Table:UpdateRaidInfo()
        WBCoalition.Table:Recalculate()
    elseif type == 'CHAT_MSG_RAID' or type == 'CHAT_MSG_RAID_LEADER' or type == 'CHAT_MSG_PARTY' or type ==
        'CHAT_MSG_PARTY_LEADER' or type == 'CHAT_MSG_WHISPER' then
        local msg, sender = ...
        local name = splitString(sender, '-')[1]
        if string.sub(msg, 1, 1) == '+' then
            local senderName = splitString(sender, '-')[1]
            local mainName = altMap[name]
            if mainName then name = mainName end
            plusInTheChat[name] = {msg = msg, sender = senderName}
            WBCoalition.Table:Recalculate()
        end
        if type == 'CHAT_MSG_WHISPER' then WBCoalition.InviteHelper:OnWhisper(name, msg) end
    elseif type == 'GROUP_ROSTER_UPDATE' then
        WBCoalition.Table:UpdateRaidInfo()
        WBCoalition.Table:Recalculate()
        WBCoalition.Sync:OnRaidStatusChange()
    elseif type == 'WHO_LIST_UPDATE' then
        WBCoalition.ScoutScanner:OnWhoResult()
    elseif type == 'LOOT_OPENED' then
        WBCoalition.LootDistributor:OnLootOpened()
    elseif type == 'CHAT_MSG_LOOT' then
        WBCoalition.LootDistributor:OnLootMessage(...)
    elseif type == 'PLAYER_TARGET_CHANGED' then
        WBCoalition.Tracker:OnTargetChanged()
    end
end

function WBCoalition:Start()
    print('start')
    WBCEventFrame:RegisterEvent('VARIABLES_LOADED')
    WBCEventFrame:RegisterEvent('CHAT_MSG_RAID')
    WBCEventFrame:RegisterEvent('CHAT_MSG_RAID_LEADER')
    WBCEventFrame:RegisterEvent('CHAT_MSG_PARTY')
    WBCEventFrame:RegisterEvent('CHAT_MSG_PARTY_LEADER')
    WBCEventFrame:RegisterEvent('CHAT_MSG_WHISPER')
    WBCEventFrame:RegisterEvent('GROUP_ROSTER_UPDATE')
    WBCEventFrame:RegisterEvent('WHO_LIST_UPDATE')
    WBCEventFrame:RegisterEvent('LOOT_OPENED')
    WBCEventFrame:RegisterEvent('PLAYER_TARGET_CHANGED')
    WBCEventFrame:RegisterEvent('CHAT_MSG_LOOT')
    WBCEventFrame:SetScript('OnEvent', processEvent)
end

WBCoalition:Start()
