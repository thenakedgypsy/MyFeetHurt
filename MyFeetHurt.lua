local ADDON_NAME = "MyFeetHurt"

-- ============================================================
-- ADDON CONFIGURATION & CONSTANTS (Fiddle with these freely!)
-- ============================================================
local CONFIG = {
    -- Window dimensions & layout
    WINDOW_WIDTH = 300,
    WINDOW_HEIGHT = 280,
    ROW_SPACING = -2,          -- Vertical space between text rows
    TOP_PADDING = -28,         -- Distance from top of window to first text row
    BUTTON_BOTTOM_PADDING = 8, -- Distance of the bottom buttons from window edge

    -- Color themes (Hex codes without the leading '|c' or with it depending on usage)
    COLOR_ALLIANCE = "FF0070DE",
    COLOR_HORDE = "FFFF2020",
    COLOR_TOTALS = "FFFFFFFF",       -- Color for main totals (Walked, Ridden, Flown, Swum, Fallen)
    COLOR_SUBTOTALS = "FFE6B800",    -- Color for general sub-stats (Alive, Dead, Unmounted, Mounted)
    COLOR_FALLEN_SUB = "FFCC9900",   -- Special sub-color for fallen alive/dead details
}

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
    milesSwumUnmounted = 0,
    milesSwumMounted = 0,
    milesFallen = 0,
    milesFallenAlive = 0,
    milesFallenDead = 0,
    milesFallenUnmounted = 0,
    milesFallenMounted = 0,
    walkedMilestone = 0,
    riddenMilestone = 0,
    flownMilestone = 0,
    swumMilestone = 0,
    fallenMilestone = 0,
    travelledMilestone = 0,
}

local DEFAULT_SETTINGS = {
    minimapPos = 220,
    useKm = false,
}

local function InitializeSavedVariables()
    MyFeetHurtDB = MyFeetHurtDB or {}
    MyFeetHurtSettings = MyFeetHurtSettings or {}

    for key, value in pairs(DEFAULT_DB) do
        if MyFeetHurtDB[key] == nil then
            MyFeetHurtDB[key] = value
        end
    end

    for key, value in pairs(DEFAULT_SETTINGS) do
        if MyFeetHurtSettings[key] == nil then
            MyFeetHurtSettings[key] = value
        end
    end
end

-- On startup, reconcile any untracked gaps in stats
local function ReconcileStats()
    local db = MyFeetHurtDB
    local walkedGap = (db.milesWalked or 0) - ((db.milesWalkedAlive or 0) + (db.milesWalkedDead or 0))
    if walkedGap > 0 then
        db.milesWalkedAlive = (db.milesWalkedAlive or 0) + walkedGap
    end

    local fallenGapAliveDead = (db.milesFallen or 0) - ((db.milesFallenAlive or 0) + (db.milesFallenDead or 0))
    if fallenGapAliveDead > 0 and (db.milesFallenAlive == 0 and db.milesFallenDead == 0) then
        db.milesFallenAlive = (db.milesFallen or 0)
    elseif fallenGapAliveDead > 0 then
        db.milesFallenAlive = (db.milesFallenAlive or 0) + fallenGapAliveDead
    end

    local fallenGapUnmountMount = (db.milesFallen or 0) - ((db.milesFallenUnmounted or 0) + (db.milesFallenMounted or 0))
    if fallenGapUnmountMount > 0 and (db.milesFallenUnmounted == 0 and db.milesFallenMounted == 0) then
        db.milesFallenUnmounted = (db.milesFallen or 0)
    elseif fallenGapUnmountMount > 0 then
        db.milesFallenUnmounted = (db.milesFallenUnmounted or 0) + fallenGapUnmountMount
    end
end

-- ============================================================
-- State & Tracking Frames
-- ============================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local distanceTracker = CreateFrame("Frame")

local lastUpdate = 0
local updateInterval = 0.2
local lastY, lastX, lastZ = nil, nil, nil
local YARDS_TO_MILES = 1 / 1760
local MILES_TO_KM = 1.609344

local statTexts = {}
local uiCreated = false
local unitButton
local titleText -- Reference to window title

-- ============================================================
-- Milestone Logic
-- ============================================================

local function GetNextMilestone(m)
    if m < 1 then return 1
    elseif m < 2 then return 2
    elseif m < 3 then return 3
    elseif m < 4 then return 4
    elseif m < 5 then return 5
    elseif m < 10 then return 10
    elseif m < 20 then return 20
    elseif m < 50 then return 50
    elseif m < 100 then return 100
    else return m + 100 end
end

local function CheckAndNotifyMilestones(milestoneKey, baseMiles, pastMethod, continuousMethod)
    local useKm = MyFeetHurtSettings and MyFeetHurtSettings.useKm
    local unitName = useKm and "Km" or "Miles"
    local factor = useKm and MILES_TO_KM or 1
    local currentVal = baseMiles * factor

    local lastM = MyFeetHurtDB[milestoneKey] or 0
    local nextM = GetNextMilestone(lastM)

    while currentVal >= nextM do
        local faction = UnitFactionGroup("player")
        local factionHex = (faction == "Horde") and CONFIG.COLOR_HORDE or CONFIG.COLOR_ALLIANCE
        local msg = string.format("My Feet Hurt: Congratulations!! You've %s %d %s! - Keep on %s!!", pastMethod, nextM, unitName, continuousMethod)
        local coloredMsg = string.format("|c%s%s|r", factionHex, msg)
        
        -- Print to chat
        print(coloredMsg)
        
        -- Display as Raid Warning banner across the middle of the screen
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, coloredMsg, ChatTypeInfo["RAID_WARNING"])
        end
        
        -- Play sound ID 5274 (Queue Pop / Ready Check chime)
        PlaySound(5274, "Master")

        MyFeetHurtDB[milestoneKey] = nextM
        lastM = nextM
        nextM = GetNextMilestone(lastM)
    end
end

local function CheckAllMilestones()
    local db = MyFeetHurtDB
    CheckAndNotifyMilestones("walkedMilestone", db.milesWalked or 0, "walked", "walking")
    CheckAndNotifyMilestones("riddenMilestone", db.milesRidden or 0, "ridden", "riding")
    CheckAndNotifyMilestones("flownMilestone", db.milesFlown or 0, "flown", "flying")
    CheckAndNotifyMilestones("swumMilestone", db.milesSwum or 0, "swum", "swimming")
    CheckAndNotifyMilestones("fallenMilestone", db.milesFallen or 0, "fallen", "falling")

    local totalBaseMiles = (db.milesWalked or 0) + (db.milesRidden or 0) + (db.milesFlown or 0) + (db.milesSwum or 0) + (db.milesFallen or 0)
    CheckAndNotifyMilestones("travelledMilestone", totalBaseMiles, "travelled", "travelling")
end

-- ============================================================
-- Utility & UI Updates
-- ============================================================

local function RecalculateGlobalValues()
    if not MyFeetHurtUI or not MyFeetHurtUI:IsShown() then
        return
    end

    local db = MyFeetHurtDB

    local useKm = MyFeetHurtSettings and MyFeetHurtSettings.useKm
    local unitName = useKm and "Km" or "Miles"
    local factor = useKm and MILES_TO_KM or 1
    local travelledTotal = ((db.milesWalked or 0) + (db.milesRidden or 0) + (db.milesFlown or 0) + (db.milesSwum or 0) + (db.milesFallen or 0)) * factor

    if unitButton then
        unitButton:SetText(useKm and "Switch to Miles" or "Switch to Km")
    end

    local faction = UnitFactionGroup("player")
    local factionHex = (faction == "Horde") and ("|c" .. CONFIG.COLOR_HORDE) or ("|c" .. CONFIG.COLOR_ALLIANCE)
    local fr, fg, fb = (faction == "Horde") and 1 or 0, (faction == "Horde") and 0.12 or 0.44, (faction == "Horde") and 0.12 or 0.87

    if titleText then
        titleText:SetTextColor(fr, fg, fb)
    end

    local displayStrings = {
        factionHex .. "[ Out of Combat Travel Stats ]|r",
        string.format("|c%sWalked Total: %.2f %s|r", CONFIG.COLOR_TOTALS, (db.milesWalked or 0) * factor, unitName),
        string.format("|c%sAlive: %.2f %s|r", CONFIG.COLOR_SUBTOTALS, (db.milesWalkedAlive or 0) * factor, unitName),
        string.format("|c%sDead: %.2f %s|r", CONFIG.COLOR_SUBTOTALS, (db.milesWalkedDead or 0) * factor, unitName),
        string.format("|c%sRidden: %.2f %s|r", CONFIG.COLOR_TOTALS, (db.milesRidden or 0) * factor, unitName),
        string.format("|c%sFlown: %.2f %s|r", CONFIG.COLOR_TOTALS, (db.milesFlown or 0) * factor, unitName),
        string.format("|c%sSwum Total: %.2f %s|r", CONFIG.COLOR_TOTALS, (db.milesSwum or 0) * factor, unitName),
        string.format("|c%sUnmounted: %.2f %s|r", CONFIG.COLOR_SUBTOTALS, (db.milesSwumUnmounted or 0) * factor, unitName),
        string.format("|c%sMounted: %.2f %s|r", CONFIG.COLOR_SUBTOTALS, (db.milesSwumMounted or 0) * factor, unitName),
        string.format("|c%sFallen Total: %.2f %s|r", CONFIG.COLOR_TOTALS, (db.milesFallen or 0) * factor, unitName),
        string.format("|c%sUnmounted: %.2f %s|r", CONFIG.COLOR_SUBTOTALS, (db.milesFallenUnmounted or 0) * factor, unitName),
        string.format("|c%sAlive: %.2f %s|r", CONFIG.COLOR_FALLEN_SUB, (db.milesFallenAlive or 0) * factor, unitName),
        string.format("|c%sDead: %.2f %s|r", CONFIG.COLOR_FALLEN_SUB, (db.milesFallenDead or 0) * factor, unitName),
        string.format("|c%sMounted: %.2f %s|r", CONFIG.COLOR_SUBTOTALS, (db.milesFallenMounted or 0) * factor, unitName),
        string.format(factionHex .. "Travelled Total: %.2f %s|r", travelledTotal, unitName),
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

local function CreateMyFeetHurtUI()
    if uiCreated and MyFeetHurtUI then
        return
    end

    if MyFeetHurtUI then
        uiCreated = true
        return
    end

    -- Main Stats Panel (Uses CONFIG values)
    local panel = CreateFrame("Frame", "MyFeetHurtUI", UIParent, "BackdropTemplate")
    panel:SetSize(CONFIG.WINDOW_WIDTH, CONFIG.WINDOW_HEIGHT)
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

    -- Title Header
    titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("TOP", panel, "TOP", 0, -8)
    titleText:SetText("My Feet Hurt")

    for i = 1, 15 do
        local fontObj = "GameFontNormal"
        if i == 1 then
            fontObj = "GameFontHighlight"
        elseif i == 15 then
            fontObj = "GameFontNormalLarge"
        end

        local fs = panel:CreateFontString(nil, "ARTWORK", fontObj)
        fs:SetJustifyH("CENTER")
        if i == 1 then
            fs:SetPoint("TOP", panel, "TOP", 0, CONFIG.TOP_PADDING)
        else
            fs:SetPoint("TOP", statTexts[i - 1], "BOTTOM", 0, CONFIG.ROW_SPACING)
        end
        statTexts[i] = fs
    end

    -- Unit toggle button (Left side of bottom bar)
    unitButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    unitButton:SetSize(130, 22)
    unitButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 15, CONFIG.BUTTON_BOTTOM_PADDING)
    unitButton:SetScript("OnClick", function()
        local oldUseKm = MyFeetHurtSettings.useKm
        MyFeetHurtSettings.useKm = not MyFeetHurtSettings.useKm
        local newUseKm = MyFeetHurtSettings.useKm

        local ratio = newUseKm and MILES_TO_KM or (1 / MILES_TO_KM)
        for _, key in ipairs({"walkedMilestone", "riddenMilestone", "flownMilestone", "swumMilestone", "fallenMilestone", "travelledMilestone"}) do
            if MyFeetHurtDB[key] and MyFeetHurtDB[key] > 0 then
                MyFeetHurtDB[key] = MyFeetHurtDB[key] * ratio
            end
        end

        RecalculateGlobalValues()
    end)

    -- Reset All button (Right side of bottom bar)
    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(130, 22)
    resetButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -15, CONFIG.BUTTON_BOTTOM_PADDING)
    resetButton:SetText("Reset All")
    resetButton:SetScript("OnClick", function()
        for key, value in pairs(DEFAULT_DB) do
            MyFeetHurtDB[key] = value
        end
        RecalculateGlobalValues()
        print("|cFFFF0000[MyFeetHurt] All stats and milestones have been reset to 0!|r")
    end)

    panel:SetScript("OnShow", RecalculateGlobalValues)

    -- Draggable Minimap Button
    local minimapButton = CreateFrame("Button", "MyFeetHurtMinimapButton", Minimap)
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
        local angle = math.rad(MyFeetHurtSettings.minimapPos or 220)
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

            MyFeetHurtSettings.minimapPos = math.deg(math.atan2(cy - my, cx - mx))
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
        if MyFeetHurtUI:IsShown() then MyFeetHurtUI:Hide() else MyFeetHurtUI:Show() end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        if isDragging then return end

        local db = MyFeetHurtDB
        local useKm = MyFeetHurtSettings.useKm
        local unitName = useKm and "Km" or "Miles"
        local factor = useKm and MILES_TO_KM or 1

        local walkedTotal  = (db.milesWalked or 0) * factor
        local walkedAlive  = (db.milesWalkedAlive or 0) * factor
        local walkedDead   = (db.milesWalkedDead or 0) * factor
        local ridden       = (db.milesRidden or 0) * factor
        local flown        = (db.milesFlown or 0) * factor
        local swumTotal    = (db.milesSwum or 0) * factor
        local swumUnmount  = (db.milesSwumUnmounted or 0) * factor
        local swumMount    = (db.milesSwumMounted or 0) * factor
        local fallenTotal  = (db.milesFallen or 0) * factor
        local fallenUnm    = (db.milesFallenUnmounted or 0) * factor
        local fallenAlive  = (db.milesFallenAlive or 0) * factor
        local fallenDead   = (db.milesFallenDead or 0) * factor
        local fallenMnt    = (db.milesFallenMounted or 0) * factor
        local travelled    = (walkedTotal + ridden + flown + swumTotal + fallenTotal)

        local faction = UnitFactionGroup("player")
        local fr, fg, fb = 0, 0.44, 0.87
        if faction == "Horde" then
            fr, fg, fb = 1, 0.12, 0.12
        end

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("My Feet Hurt", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Walked Total:", string.format("%.2f %s", walkedTotal, unitName), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("   Alive:", string.format("%.2f %s", walkedAlive, unitName), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("   Dead:", string.format("%.2f %s", walkedDead, unitName), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("Ridden:", string.format("%.2f %s", ridden, unitName), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Flown:", string.format("%.2f %s", flown, unitName), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Swum Total:", string.format("%.2f %s", swumTotal, unitName), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("   Unmounted:", string.format("%.2f %s", swumUnmount, unitName), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("   Mounted:", string.format("%.2f %s", swumMount, unitName), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("Fallen Total:", string.format("%.2f %s", fallenTotal, unitName), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("   Unmounted:", string.format("%.2f %s", fallenUnm, unitName), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("      Alive:", string.format("%.2f %s", fallenAlive, unitName), 0.8, 0.6, 0, 0.8, 0.6, 0)
        GameTooltip:AddDoubleLine("      Dead:", string.format("%.2f %s", fallenDead, unitName), 0.8, 0.6, 0, 0.8, 0.6, 0)
        GameTooltip:AddDoubleLine("   Mounted:", string.format("%.2f %s", fallenMnt, unitName), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Travelled Total:", string.format("%.2f %s", travelled, unitName), fr, fg, fb, fr, fg, fb)
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
        CreateMyFeetHurtUI()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckAllMilestones()
        RecalculateGlobalValues()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

-- ============================================================
-- Distance tracking
-- ============================================================

distanceTracker:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < updateInterval then return end

    if not MyFeetHurtDB then
        InitializeSavedVariables()
    end

    if not InCombatLockdown() then
        local currentY, currentX, currentZ = UnitPosition("player")

        if currentY and currentX and currentZ and lastY and lastX and lastZ then
            local dy = currentY - lastY
            local dx = currentX - lastX
            local dz = currentZ - lastZ
            local distanceYards = math.sqrt(dx*dx + dy*dy + dz*dz)

            if distanceYards > 0.01 and distanceYards < 150 then
                local distanceMiles = distanceYards * YARDS_TO_MILES
                
                local isFallingNow = IsFalling() or (dz < -0.2 and not IsSwimming() and not UnitOnTaxi("player"))

                if UnitOnTaxi("player") then
                    MyFeetHurtDB.milesFlown = (MyFeetHurtDB.milesFlown or 0) + distanceMiles
                    CheckAndNotifyMilestones("flownMilestone", MyFeetHurtDB.milesFlown, "flown", "flying")
                elseif IsSwimming() then
                    MyFeetHurtDB.milesSwum = (MyFeetHurtDB.milesSwum or 0) + distanceMiles
                    if IsMounted() then
                        MyFeetHurtDB.milesSwumMounted = (MyFeetHurtDB.milesSwumMounted or 0) + distanceMiles
                    else
                        MyFeetHurtDB.milesSwumUnmounted = (MyFeetHurtDB.milesSwumUnmounted or 0) + distanceMiles
                    end
                    CheckAndNotifyMilestones("swumMilestone", MyFeetHurtDB.milesSwum, "swum", "swimming")
                elseif isFallingNow then
                    MyFeetHurtDB.milesFallen = (MyFeetHurtDB.milesFallen or 0) + distanceMiles
                    if UnitIsDeadOrGhost("player") then
                        MyFeetHurtDB.milesFallenDead = (MyFeetHurtDB.milesFallenDead or 0) + distanceMiles
                    else
                        MyFeetHurtDB.milesFallenAlive = (MyFeetHurtDB.milesFallenAlive or 0) + distanceMiles
                    end
                    if IsMounted() then
                        MyFeetHurtDB.milesFallenMounted = (MyFeetHurtDB.milesFallenMounted or 0) + distanceMiles
                    else
                        MyFeetHurtDB.milesFallenUnmounted = (MyFeetHurtDB.milesFallenUnmounted or 0) + distanceMiles
                    end
                    CheckAndNotifyMilestones("fallenMilestone", MyFeetHurtDB.milesFallen, "fallen", "falling")
                elseif IsMounted() then
                    MyFeetHurtDB.milesRidden = (MyFeetHurtDB.milesRidden or 0) + distanceMiles
                    CheckAndNotifyMilestones("riddenMilestone", MyFeetHurtDB.milesRidden, "ridden", "riding")
                else
                    MyFeetHurtDB.milesWalked = (MyFeetHurtDB.milesWalked or 0) + distanceMiles
                    if UnitIsDeadOrGhost("player") then
                        MyFeetHurtDB.milesWalkedDead = (MyFeetHurtDB.milesWalkedDead or 0) + distanceMiles
                    else
                        MyFeetHurtDB.milesWalkedAlive = (MyFeetHurtDB.milesWalkedAlive or 0) + distanceMiles
                    end
                    CheckAndNotifyMilestones("walkedMilestone", MyFeetHurtDB.milesWalked, "walked", "walking")
                end

                -- Check milestones for total combined travel as well
                local totalBaseMiles = (MyFeetHurtDB.milesWalked or 0) + (MyFeetHurtDB.milesRidden or 0) + (MyFeetHurtDB.milesFlown or 0) + (MyFeetHurtDB.milesSwum or 0) + (MyFeetHurtDB.milesFallen or 0)
                CheckAndNotifyMilestones("travelledMilestone", totalBaseMiles, "travelled", "travelling")

                RecalculateGlobalValues()
            end
        end

        lastY, lastX, lastZ = currentY, currentX, currentZ
    end

    lastUpdate = 0
end)

-- ============================================================
-- Slash command
-- ============================================================

SLASH_MYFEETHURT1 = "/mfh"
SLASH_MYFEETHURT2 = "/myfeethurt"
SlashCmdList["MYFEETHURT"] = function()
    InitializeSavedVariables()
    if not uiCreated or not MyFeetHurtUI then
        CreateMyFeetHurtUI()
    end
    if MyFeetHurtUI:IsShown() then
        MyFeetHurtUI:Hide()
    else
        MyFeetHurtUI:Show()
    end
end