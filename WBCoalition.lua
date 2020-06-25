SLASH_WBC1 = "/wbc"

WBCIcon = {}
WBCDB = {players = {}, altMap = {}, lastUpdate = {}}
WBCCache = {classes = {}, tracks = {}, loogLot = {}}
WBCTemp = {normalizedStrings = {}}

WBC_CLASS_COLOR_NONE = '|cffc2b5b5'

WBC_WORLD_BOSSES = {'Lord Kazzak', 'Azuregos', 'Lethon', 'Ysondre', 'Taerar', 'Emeriss'}

WBC_BOSS_DATA = {
    ['Lord Kazzak'] = {
        loot = {18546, 17111, 18204, 19135, 18544, 19134, 19133, 18543, 17112, 17113, 18665}
    }
}

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

local function createDropdown(node)
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
    info.func = function() WBCTable:Show() end
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
        WBCTable:Recalculate()
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
                    WBCTable:Show()
                end
            elseif button == 'RightButton' then
                GameTooltip:Hide()
                UIDropDownMenu_Initialize(WBCTableDropDownMenu, createDropdown, "MENU")
                UIDropDownMenu_SetAnchor(WBCTableDropDownMenu, 0, 0, "TOPRIGHT", icon, "BOTTOMLEFT")
                CloseDropDownMenus(1)
                ToggleDropDownMenu(1, nil, WBCTableDropDownMenu)
            else
                WBCScoutScanner:Scan()
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

function SlashCmdList.WBC(cmd) WBCLootDistributor:OnCommand(cmd) end
