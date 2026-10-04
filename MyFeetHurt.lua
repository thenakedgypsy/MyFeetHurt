local ADDON_NAME = "StatTracker"

-- ============================================================
-- Saved variables
-- ============================================================

local DEFAULT_DB = {
    milesWalked = 0,
    milesWalkedAlive = 0,
    milesWalkedDead = 0,
    milesFlown = 0,
    milesRidden = 0,
    milesSwum = 0,
    walkedMilestone = 0,
    riddenMilestone = 0,
    flownMilestone = 0,
    swumMilestone = 0,
}

local DEFAULT_SETTINGS = {
    minimapPos = 220,
    useKm = false,
}

local function InitializeSavedVariables()
    StatTrackerDB = StatTrackerDB or {}
    StatTrackerSettings = StatTrackerSettings or {}

    for key, value in pairs(DEFAULT_DB) do
        if StatTrackerDB[key] == nil then
            StatTrackerDB[key] = value
        end
    end

    for key, value in pairs(DEFAULT_SETTINGS) do
        if StatTrackerSettings[key] == nil then
            StatTrackerSettings[key] = value
        end
    end
end

-- On startup, any walking distance not accounted for by Alive + Dead is assumed to be walked alive.
local function ReconcileStats()
    local db = StatTrackerDB
    local walkedGap = (db.milesWalked or 0) - ((db.milesWalkedAlive or 0) + (db.milesWalkedDead or 0))
    if walkedGap > 0 then
        db.milesWalkedAlive = (db.milesWalkedAlive or 0) + walkedGap
    end
end

-- ============================================================
-- State & Tracking Frames
-- ============================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local distanceTracker = CreateFrame("Frame")

local lastUpdate = 0
local YARDS_TO_MILES = 1 / 1760
local MILES_TO_KM = 1.609344

local statTexts = {}
local uiCreated = false
local unitButton

-- ============================================================
-- Milestone Logic
-- ============================================================

local function GetNextMilestone(m)
    if m < 10 then return 10
    elseif m < 20 then return 20
    elseif m < 50 then return 50
    elseif m < 100 then return 100
    else return m + 100 end
end

local function CheckAndNotifyMilestones(milestoneKey, baseMiles, pastMethod, continuousMethod)
    local useKm = StatTrackerSettings and StatTrackerSettings.useKm
    local unitName = useKm and "Km" or "Miles"
    local factor = useKm and MILES_TO_KM or 1
    local currentVal = baseMiles * factor

    local lastM = StatTrackerDB[milestoneKey] or 0
    local nextM = GetNextMilestone(lastM)

    while currentVal >= nextM do
        local msg = string.format("My Feet Hurt: Congratulations!! You've %s %d %s! - Keep on %s!!", pastMethod, nextM, unitName, continuousMethod)
        print(msg)

        StatTrackerDB[milestoneKey] = nextM
        lastM = nextM
        nextM = GetNextMilestone(lastM)
    end
end

-- ============================================================
-- Utility & UI Updates
-- ============================================================

local function RecalculateGlobalValues()
    if not StatTrackerUI or not StatTrackerUI:IsShown() then
        return
    end

    local db = StatTrackerDB

    local useKm = StatTrackerSettings and StatTrackerSettings.useKm
    local unitName = useKm and "Km" or "Miles"
    local factor = useKm and MILES_TO_KM or 1
    local travelledTotal = ((db.milesWalked or 0) + (db.milesRidden or 0) + (db.milesFlown or 0) + (db.milesSwum or 0)) * factor

    if unitButton then
        unitButton:SetText(useKm and "Switch to Miles" or "Switch to Km")
    end

    local displayStrings = {
        "|cFF00FF00[ Out of Combat Travel Stats ]|r",
        string.format("Walked Total: %.2f %s", (db.milesWalked or 0) * factor, unitName),
        string.format("   Alive: %.2f %s", (db.milesWalkedAlive or 0) * factor, unitName),
        string.format("   Dead: %.2f %s", (db.milesWalkedDead or 0) * factor, unitName),
        string.format("Ridden: %.2f %s", (db.milesRidden or 0) * factor, unitName),
        string.format("Flown: %.2f %s", (db.milesFlown or 0) * factor, unitName),
        string.format("Swum: %.2f %s", (db.milesSwum or 0) * factor, unitName),
        string.format("Travelled Total: %.2f %s", travelledTotal, unitName),
    }

    for i = 1, #displayStrings do
        if statTexts[i] then
            statTexts[i]:SetText(displayStrings[i])
            statTexts[i]:Show()
        end
    end

    for i = #displayStrings + 1, #statTexts do
        if statTexts[i] then
            statTexts[i]:Hide()
        end
    end
end

-- ============================================================
-- UI Creation
-- ============================================================

local function CreateStatTrackerUI()
    if uiCreated and StatTrackerUI then
        return
    end

    if StatTrackerUI then
        uiCreated = true
        return
    end

    -- Main Stats Panel
    local panel = CreateFrame("Frame", "StatTrackerUI", UIParent, "BackdropTemplate")
    panel:SetSize(230, 210)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()

    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.85)

    local closeBtn = CreateFrame("Button", nil, panel)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)

    local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeText:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeText:SetText("X")

    closeBtn:SetScript("OnClick", function() panel:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeText:SetTextColor(1, 0.2, 0.2) end)
    closeBtn:SetScript("OnLeave", function() closeText:SetTextColor(1, 1, 1) end)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", panel, "TOP", 0, -12)
    title:SetText("My Feet Hurt")

    for i = 1, 8 do
        local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        if i == 1 then
            fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -40)
        else
            fs:SetPoint("TOPLEFT", statTexts[i - 1], "BOTTOMLEFT", 0, -3)
        end
        statTexts[i] = fs
    end

    unitButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    unitButton:SetSize(130, 22)
    unitButton:SetPoint("BOTTOM", panel, "BOTTOM", 0, 12)
    unitButton:SetScript("OnClick", function()
        local oldUseKm = StatTrackerSettings.useKm
        StatTrackerSettings.useKm = not StatTrackerSettings.useKm
        local newUseKm = StatTrackerSettings.useKm

        -- Convert stored milestone tracker values to match unit change smoothly
        local ratio = newUseKm and MILES_TO_KM or (1 / MILES_TO_KM)
        for _, key in ipairs({"walkedMilestone", "riddenMilestone", "flownMilestone", "swumMilestone"}) do
            if StatTrackerDB[key] and StatTrackerDB[key] > 0 then
                StatTrackerDB[key] = StatTrackerDB[key] * ratio
            end
        end

        RecalculateGlobalValues()
    end)

    panel:SetScript("OnShow", RecalculateGlobalValues)

    -- Draggable Minimap Button
    local minimapButton = CreateFrame("Button", "StatTrackerMinimapButton", Minimap)
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Ability_Kick")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(52, 52)
    border:SetPoint("CENTER", minimapButton, "CENTER", 10, -10)

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function UpdateMinimapButtonPosition()
        local angle = math.rad(StatTrackerSettings.minimapPos or 220)
        local radius = 93
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end

    UpdateMinimapButtonPosition()

    local isDragging = false

    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        isDragging = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale

            StatTrackerSettings.minimapPos = math.deg(math.atan2(cy - my, cx - mx))
            UpdateMinimapButtonPosition()
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        C_Timer.After(0.1, function() isDragging = false end)
    end)

    minimapButton:RegisterForClicks("LeftButtonUp")
    minimapButton:SetScript("OnClick", function()
        if isDragging then return end
        if StatTrackerUI:IsShown() then StatTrackerUI:Hide() else StatTrackerUI:Show() end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        if isDragging then return end

        local db = StatTrackerDB
        local useKm = StatTrackerSettings.useKm
        local unitName = useKm and "Km" or "Miles"
        local factor = useKm and MILES_TO_KM or 1

        local walkedTotal = (db.milesWalked or 0) * factor
        local walkedAlive = (db.milesWalkedAlive or 0) * factor
        local walkedDead  = (db.milesWalkedDead or 0) * factor
        local ridden      = (db.milesRidden or 0) * factor
        local flown       = (db.milesFlown or 0) * factor
        local swum        = (db.milesSwum or 0) * factor
        local travelled   = (walkedTotal + ridden + flown + swum)

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("My Feet Hurt", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Walked Total:", string.format("%.2f %s", walkedTotal, unitName), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("   Alive:", string.format("%.2f %s", walkedAlive, unitName), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("   Dead:", string.format("%.2f %s", walkedDead, unitName), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("Ridden:", string.format("%.2f %s", ridden, unitName), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Flown:", string.format("%.2f %s", flown, unitName), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Swum:", string.format("%.2f %s", swum, unitName), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Travelled Total:", string.format("%.2f %s", travelled, unitName), 0, 1, 0, 0, 1, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF808080Left-Click: Toggle Frame|r")
        GameTooltip:AddLine("|cFF808080Left-Click & Drag: Move Button|r")
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    uiCreated = true
end

-- ============================================================
-- Event handling
-- ============================================================

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= ADDON_NAME then return end

        InitializeSavedVariables()
        ReconcileStats()
        CreateStatTrackerUI()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ============================================================
-- Distance tracking
-- ============================================================

distanceTracker:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < 1.0 then return end

    if not StatTrackerDB then
        InitializeSavedVariables()
    end

    if not InCombatLockdown() then
        local rawSpeed = GetUnitSpeed("player")
        local speed = tonumber(rawSpeed) or 0

        if speed > 0 then
            local distanceMiles = (speed * lastUpdate) * YARDS_TO_MILES
            if UnitOnTaxi("player") then
                StatTrackerDB.milesFlown = (StatTrackerDB.milesFlown or 0) + distanceMiles
                CheckAndNotifyMilestones("flownMilestone", StatTrackerDB.milesFlown, "flown", "flying")
            elseif IsMounted() then
                StatTrackerDB.milesRidden = (StatTrackerDB.milesRidden or 0) + distanceMiles
                CheckAndNotifyMilestones("riddenMilestone", StatTrackerDB.milesRidden, "ridden", "riding")
            elseif IsSwimming() then
                StatTrackerDB.milesSwum = (StatTrackerDB.milesSwum or 0) + distanceMiles
                CheckAndNotifyMilestones("swumMilestone", StatTrackerDB.milesSwum, "swum", "swimming")
            else
                StatTrackerDB.milesWalked = (StatTrackerDB.milesWalked or 0) + distanceMiles
                if UnitIsDeadOrGhost("player") then
                    StatTrackerDB.milesWalkedDead = (StatTrackerDB.milesWalkedDead or 0) + distanceMiles
                else
                    StatTrackerDB.milesWalkedAlive = (StatTrackerDB.milesWalkedAlive or 0) + distanceMiles
                end
                CheckAndNotifyMilestones("walkedMilestone", StatTrackerDB.milesWalked, "walked", "walking")
            end
            RecalculateGlobalValues()
        end
    end

    lastUpdate = 0
end)

-- ============================================================
-- Slash command
-- ============================================================

SLASH_STATTRACKER1 = "/st"
SlashCmdList["STATTRACKER"] = function()
    InitializeSavedVariables()
    if not uiCreated or not StatTrackerUI then
        CreateStatTrackerUI()
    end
    if StatTrackerUI:IsShown() then
        StatTrackerUI:Hide()
    else
        StatTrackerUI:Show()
    end
end