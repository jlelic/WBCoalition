WBCoalition.Tracker = {}
local Tracker = WBCoalition.Tracker

local isWBoss = {
}
for i=1,#WBCoalition.BOSS_NAMES do
    isWBoss[WBCoalition.BOSS_NAMES[i]] = true
end


local function isTargetingWorldBoss(targetName)
    return targetName and isWBoss[targetName] --and UnitClassification("target") == "worldboss"
end

function Tracker:OnTargetChanged()
    local boss = UnitName("target")
    if not isTargetingWorldBoss(boss) then return end
    WBCCache.tracks = WBCCache.tracks or {}
    local tracks = WBCCache.tracks

    tracks[boss] = tracks[boss] or { lastSeen = 0 }
    if GetServerTime() - tracks[boss].lastSeen > 10 then
        tracks[boss] = {
            lastSeen = GetServerTime(),
            zone = GetRealZoneText()
        }
    end
end