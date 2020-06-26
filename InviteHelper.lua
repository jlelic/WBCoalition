WBCoalition.InviteHelper = {}

InviteHelper = WBCoalition.InviteHelper

local function shouldInvite(msg)
    local msgLower = strlower(msg)
    if LeaPlusDB then
        local _,_,_,_,_,_,textBox = LeaPlusGlobalPanel_InvPanel:GetChildren()
        if textBox:GetText() ~= '' then
            if strlower(textBox:GetText()) == msgLower then
                return true
            end
        elseif strlower(LeaPlusDB["InvKey"]) == msgLower then
            return true
        end
    end

    if VExRT then
        local invWords = { strsplit(' ', VExRT.InviteTool.Words) }
        for i=1,#invWords do
            if strlower(invWords[i]) == msgLower then
                return true
            end
        end
    end

    return  false
end

local function getPointsFor(name)
    local mainName = WBCDB.altMap[name]
    if not mainName then return nil end
    return WBCDB.players[mainName].points, mainName
end

function InviteHelper:OnWhisper(name, msg)
    if shouldInvite(msg) then
        local points, mainName = getPointsFor(name)
        if points == nil then return end

        local logMsg= WBCoalition:GetClassColoredName(name) .. '|r has |cffffff00' .. points .. '|r points'
        if name ~= mainName then
            logMsg = logMsg .. ' (main character ' .. WBCoalition:GetClassColoredName(mainName) .. '|r)'
        end
        WBCoalition:Log(logMsg)
    end
end
