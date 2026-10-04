local ADDON_NAME = "MyFeetHurt"

-- ============================================================
-- ADDON CONFIGURATION & CONSTANTS (Fiddle with these freely!)
-- ============================================================
local CONFIG = {
    -- Window dimensions & layout
    WINDOW_WIDTH = 320,
    WINDOW_HEIGHT = 440,       -- Initial height only; the window then resizes itself to fit its rows
    ROW_SPACING = -2,          -- Vertical space between text rows
    TOP_PADDING = -32,         -- Distance from top of window to first text row
    BUTTON_BOTTOM_PADDING = 8, -- Distance of the bottom buttons from window edge
    CONTENT_BOTTOM_PADDING = 6, -- Gap between the last text row and the bottom button

    -- Color themes (Hex codes without the leading '|c' or with it depending on usage)
    COLOR_ALLIANCE = "FF0070DE",
    COLOR_HORDE = "FFFF2020",
    COLOR_TOTALS = "FFFFFFFF",       -- Color for main totals (Walked, Ridden, Flown, Swum, Airborne, Public Transport)
    COLOR_SUBTOTALS = "FFE6B800",    -- Color for general sub-stats (Alive, Dead, Unmounted, Mounted)
    COLOR_AIRBORNE_SUB = "FFCC9900", -- Special sub-color for sub-details

    -- Window refresh
    UI_REFRESH_INTERVAL = 0.25, -- Seconds between window updates while it is open

    -- Public transport detection
    BOAT_ENTER_DELAY = 1.0,    -- Seconds of sustained speed mismatch required before counting as public transport
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
    milesBoats = 0,
    milesBoatsAlive = 0,
    milesBoatsDead = 0,
    milesSwum = 0,
    milesSwumUnmounted = 0,
    milesSwumUnmountedAlive = 0,
    milesSwumUnmountedDead = 0,
    milesSwumMounted = 0,
    milesAirborne = 0,
    milesAirborneAlive = 0,
    milesAirborneDead = 0,
    milesAirborneUnmounted = 0,
    milesAirborneMounted = 0,
    walkedMilestone = 0,
    riddenMilestone = 0,
    flownMilestone = 0,
    boatsMilestone = 0,
    swumMilestone = 0,
    airborneMilestone = 0,
    travelledMilestone = 0,
}

local DEFAULT_SETTINGS = {
    minimapPos = 220,
    useKm = false,
}

local function InitializeSavedVariables()
    MyFeetHurtDB = MyFeetHurtDB or {}
    MyFeetHurtSettings = MyFeetHurtSettings or {}

    -- Backwards compatibility: Migrate old fallen stats to airborne if they exist
    if MyFeetHurtDB.milesFallen ~= nil and MyFeetHurtDB.milesAirborne == nil then
        MyFeetHurtDB.milesAirborne = MyFeetHurtDB.milesFallen
        MyFeetHurtDB.milesAirborneAlive = MyFeetHurtDB.milesFallenAlive
        MyFeetHurtDB.milesAirborneDead = MyFeetHurtDB.milesFallenDead
        MyFeetHurtDB.milesAirborneUnmounted = MyFeetHurtDB.milesFallenUnmounted
        MyFeetHurtDB.milesAirborneMounted = MyFeetHurtDB.milesFallenMounted
        MyFeetHurtDB.airborneMilestone = MyFeetHurtDB.fallenMilestone or 0
    end

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

    local boatsGapAliveDead = (db.milesBoats or 0) - ((db.milesBoatsAlive or 0) + (db.milesBoatsDead or 0))
    if boatsGapAliveDead > 0 and (db.milesBoatsAlive == 0 and db.milesBoatsDead == 0) then
        db.milesBoatsAlive = (db.milesBoats or 0)
    elseif boatsGapAliveDead > 0 then
        db.milesBoatsAlive = (db.milesBoatsAlive or 0) + boatsGapAliveDead
    end

    local airborneGapAliveDead = (db.milesAirborne or 0) - ((db.milesAirborneAlive or 0) + (db.milesAirborneDead or 0))
    if airborneGapAliveDead > 0 and (db.milesAirborneAlive == 0 and db.milesAirborneDead == 0) then
        db.milesAirborneAlive = (db.milesAirborne or 0)
    elseif airborneGapAliveDead > 0 then
        db.milesAirborneAlive = (db.milesAirborneAlive or 0) + airborneGapAliveDead
    end

    local airborneGapUnmountMount = (db.milesAirborne or 0) - ((db.milesAirborneUnmounted or 0) + (db.milesAirborneMounted or 0))
    if airborneGapUnmountMount > 0 and (db.milesAirborneUnmounted == 0 and db.milesAirborneMounted == 0) then
        db.milesAirborneUnmounted = (db.milesAirborne or 0)
    elseif airborneGapUnmountMount > 0 then
        db.milesAirborneUnmounted = (db.milesAirborneUnmounted or 0) + airborneGapUnmountMount
    end

    local swumUnmountGapAliveDead = (db.milesSwumUnmounted or 0) - ((db.milesSwumUnmountedAlive or 0) + (db.milesSwumUnmountedDead or 0))
    if swumUnmountGapAliveDead > 0 and (db.milesSwumUnmountedAlive == 0 and db.milesSwumUnmountedDead == 0) then
        db.milesSwumUnmountedAlive = (db.milesSwumUnmounted or 0)
    elseif swumUnmountGapAliveDead > 0 then
        db.milesSwumUnmountedAlive = (db.milesSwumUnmountedAlive or 0) + swumUnmountGapAliveDead
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
local updateInterval = 0.04
local lastY, lastX, lastZ = nil, nil, nil
local YARDS_TO_MILES = 1 / 1760
local MILES_TO_KM = 1.609344

local statTexts = {}
local uiCreated = false
local unitButton
local titleText -- Reference to window title

-- Collapse/expand support
-- ROW_PARENT: row index -> index of the row that controls its visibility
-- COLLAPSIBLE: row indexes that act as clickable headers
local collapsedRows = {}
local layoutDirty = true  -- Row layout/window height only needs redoing when this is set
local lastRowText = {}   -- Last text applied to each row, to skip redundant SetText calls
local toggleButtons = {}
local ROW_PARENT = {
    [3] = 2, [4] = 2,                              -- Walked: Alive, Dead
    [8] = 7, [9] = 7,                              -- Public Transport: Alive, Dead
    [11] = 10, [12] = 11, [13] = 11, [14] = 10,    -- Swum: Unmounted (Alive, Dead), Mounted
    [16] = 15, [17] = 16, [18] = 16, [19] = 15,    -- Airborne: Unmounted (Alive, Dead), Mounted
}
local COLLAPSIBLE = { [2] = true, [7] = true, [10] = true, [11] = true, [15] = true, [16] = true }

-- Formats a distance given in miles according to the current unit setting.
-- Miles: "x.xx Miles". Km mode: meters below 1 km, then "x.xx Km".
local function FormatDistance(miles)
    if MyFeetHurtSettings and MyFeetHurtSettings.useKm then
        local km = miles * MILES_TO_KM
        if km < 1 then
            return string.format("%.0f m", km * 1000)
        end
        return string.format("%.2f Km", km)
    end
    return string.format("%.2f Miles", miles)
end

local function IsRowVisible(i)
    local parent = ROW_PARENT[i]
    while parent do
        if collapsedRows[parent] then
            return false
        end
        parent = ROW_PARENT[parent]
    end
    return true
end

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
        
        print(coloredMsg)
        
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, coloredMsg, ChatTypeInfo["RAID_WARNING"])
        end
        
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
    CheckAndNotifyMilestones("boatsMilestone", db.milesBoats or 0, "used public transportation", "traveling via public transport")
    CheckAndNotifyMilestones("swumMilestone", db.milesSwum or 0, "swum", "swimming")
    CheckAndNotifyMilestones("airborneMilestone", db.milesAirborne or 0, "been airborne", "jumping and falling")

    local totalBaseMiles = (db.milesWalked or 0) + (db.milesRidden or 0) + (db.milesFlown or 0) + (db.milesBoats or 0) + (db.milesSwum or 0) + (db.milesAirborne or 0)
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
    local travelledTotal = (db.milesWalked or 0) + (db.milesRidden or 0) + (db.milesFlown or 0) + (db.milesBoats or 0) + (db.milesSwum or 0) + (db.milesAirborne or 0)

    if unitButton then
        unitButton:SetText(useKm and "Imperial" or "Metric")
    end

    local faction = UnitFactionGroup("player")
    local factionHex = (faction == "Horde") and ("|c" .. CONFIG.COLOR_HORDE) or ("|c" .. CONFIG.COLOR_ALLIANCE)
    local fr, fg, fb = (faction == "Horde") and 1 or 0, (faction == "Horde") and 0.12 or 0.44, (faction == "Horde") and 0.12 or 0.87

    if titleText then
        titleText:SetTextColor(fr, fg, fb)
    end

    local displayStrings = {
        factionHex .. "[ Out of Combat Travel Stats ]|r",
        string.format("|c%sWalking: %s|r", CONFIG.COLOR_TOTALS, FormatDistance(db.milesWalked or 0)),
        string.format("|c%sAlive: %s|r", CONFIG.COLOR_SUBTOTALS, FormatDistance(db.milesWalkedAlive or 0)),
        string.format("|c%sDead: %s|r", CONFIG.COLOR_SUBTOTALS, FormatDistance(db.milesWalkedDead or 0)),
        string.format("|c%sRiding: %s|r", CONFIG.COLOR_TOTALS, FormatDistance(db.milesRidden or 0)),
        string.format("|c%sFlight Path: %s|r", CONFIG.COLOR_TOTALS, FormatDistance(db.milesFlown or 0)),
        string.format("|c%sPublic Transport: %s|r", CONFIG.COLOR_TOTALS, FormatDistance(db.milesBoats or 0)),
        string.format("|c%sAlive: %s|r", CONFIG.COLOR_AIRBORNE_SUB, FormatDistance(db.milesBoatsAlive or 0)),
        string.format("|c%sDead: %s|r", CONFIG.COLOR_AIRBORNE_SUB, FormatDistance(db.milesBoatsDead or 0)),
        string.format("|c%sSwimming: %s|r", CONFIG.COLOR_TOTALS, FormatDistance(db.milesSwum or 0)),
        string.format("|c%sUnmounted: %s|r", CONFIG.COLOR_SUBTOTALS, FormatDistance(db.milesSwumUnmounted or 0)),
        string.format("|c%sAlive: %s|r", CONFIG.COLOR_AIRBORNE_SUB, FormatDistance(db.milesSwumUnmountedAlive or 0)),
        string.format("|c%sDead: %s|r", CONFIG.COLOR_AIRBORNE_SUB, FormatDistance(db.milesSwumUnmountedDead or 0)),
        string.format("|c%sMounted: %s|r", CONFIG.COLOR_SUBTOTALS, FormatDistance(db.milesSwumMounted or 0)),
        string.format("|c%sAirborne: %s|r", CONFIG.COLOR_TOTALS, FormatDistance(db.milesAirborne or 0)),
        string.format("|c%sUnmounted: %s|r", CONFIG.COLOR_SUBTOTALS, FormatDistance(db.milesAirborneUnmounted or 0)),
        string.format("|c%sAlive: %s|r", CONFIG.COLOR_AIRBORNE_SUB, FormatDistance(db.milesAirborneAlive or 0)),
        string.format("|c%sDead: %s|r", CONFIG.COLOR_AIRBORNE_SUB, FormatDistance(db.milesAirborneDead or 0)),
        string.format("|c%sMounted: %s|r", CONFIG.COLOR_SUBTOTALS, FormatDistance(db.milesAirborneMounted or 0)),
        factionHex .. "Total Distance Travelled:|r",
        factionHex .. FormatDistance(travelledTotal) .. "|r",
    }

    for i = 1, #displayStrings do
        local fs = statTexts[i]
        if fs then
            local text = displayStrings[i]
            if COLLAPSIBLE[i] then
                text = (collapsedRows[i] and "|cFFFFFFFF[+]|r " or "|cFFFFFFFF[-]|r ") .. text
            end
            if lastRowText[i] ~= text then
                fs:SetText(text)
                lastRowText[i] = text
            end
        end
    end

    if layoutDirty then
        layoutDirty = false

        local previousRow
        local contentHeight = 0
        local visibleCount = 0
        for i = 1, #displayStrings do
            local fs = statTexts[i]
            if fs then
                if IsRowVisible(i) then
                    fs:ClearAllPoints()
                    if previousRow then
                        fs:SetPoint("TOP", previousRow, "BOTTOM", 0, CONFIG.ROW_SPACING)
                    else
                        fs:SetPoint("TOP", MyFeetHurtUI, "TOP", 0, CONFIG.TOP_PADDING)
                    end
                    fs:Show()
                    if toggleButtons[i] then toggleButtons[i]:Show() end
                    previousRow = fs
                    contentHeight = contentHeight + fs:GetStringHeight()
                    visibleCount = visibleCount + 1
                else
                    fs:Hide()
                    if toggleButtons[i] then toggleButtons[i]:Hide() end
                end
            end
        end

        local buttonHeight = unitButton and unitButton:GetHeight() or 22
        local totalHeight = -CONFIG.TOP_PADDING
            + contentHeight
            + (visibleCount - 1) * -CONFIG.ROW_SPACING
            + CONFIG.CONTENT_BOTTOM_PADDING
            + buttonHeight
            + CONFIG.BUTTON_BOTTOM_PADDING
        MyFeetHurtUI:SetHeight(totalHeight)
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

    titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("TOP", panel, "TOP", 0, -8)
    titleText:SetText("My Feet Hurt")

    for i = 1, 21 do
        local fontObj = "GameFontNormal"
        if i == 1 or i == 20 or i == 21 then
            fontObj = "GameFontHighlightLarge"
        elseif i == 2 or i == 5 or i == 6 or i == 7 or i == 10 or i == 15 then
            fontObj = "GameFontNormalLarge"
        end

        local fs = panel:CreateFontString(nil, "ARTWORK", fontObj)
        fs:SetJustifyH("CENTER")
        if i == 21 then
            local fontPath, fontSize, fontFlags = fs:GetFont()
            fs:SetFont(fontPath, fontSize + 4, fontFlags)
        end
        if i == 1 then
            fs:SetPoint("TOP", panel, "TOP", 0, CONFIG.TOP_PADDING)
        else
            fs:SetPoint("TOP", statTexts[i - 1], "BOTTOM", 0, CONFIG.ROW_SPACING)
        end
        statTexts[i] = fs

        if COLLAPSIBLE[i] then
            local toggle = CreateFrame("Button", nil, panel)
            toggle:SetAllPoints(fs)
            toggle:RegisterForClicks("LeftButtonUp")
            toggle:SetScript("OnClick", function()
                collapsedRows[i] = not collapsedRows[i]
                layoutDirty = true
                RecalculateGlobalValues()
            end)
            toggleButtons[i] = toggle
        end
    end

    unitButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    unitButton:SetSize(130, 22)
    unitButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 15, CONFIG.BUTTON_BOTTOM_PADDING)
    unitButton:SetScript("OnClick", function()
        local oldUseKm = MyFeetHurtSettings.useKm
        MyFeetHurtSettings.useKm = not MyFeetHurtSettings.useKm
        local newUseKm = MyFeetHurtSettings.useKm

        local ratio = newUseKm and MILES_TO_KM or (1 / MILES_TO_KM)
        for _, key in ipairs({"walkedMilestone", "riddenMilestone", "flownMilestone", "boatsMilestone", "swumMilestone", "airborneMilestone", "travelledMilestone"}) do
            if MyFeetHurtDB[key] and MyFeetHurtDB[key] > 0 then
                MyFeetHurtDB[key] = MyFeetHurtDB[key] * ratio
            end
        end

        RecalculateGlobalValues()
    end)

    panel:SetScript("OnShow", function()
        layoutDirty = true
        RecalculateGlobalValues()
    end)

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

        local walkedTotal     = (db.milesWalked or 0)
        local walkedAlive     = (db.milesWalkedAlive or 0)
        local walkedDead      = (db.milesWalkedDead or 0)
        local ridden          = (db.milesRidden or 0)
        local flown           = (db.milesFlown or 0)
        local boatsTotal      = (db.milesBoats or 0)
        local boatsAlive      = (db.milesBoatsAlive or 0)
        local boatsDead       = (db.milesBoatsDead or 0)
        local swumTotal       = (db.milesSwum or 0)
        local swumUnm         = (db.milesSwumUnmounted or 0)
        local swumUnmAlive    = (db.milesSwumUnmountedAlive or 0)
        local swumUnmDead     = (db.milesSwumUnmountedDead or 0)
        local swumMount       = (db.milesSwumMounted or 0)
        local airborneTotal   = (db.milesAirborne or 0)
        local airborneUnm     = (db.milesAirborneUnmounted or 0)
        local airborneAlive   = (db.milesAirborneAlive or 0)
        local airborneDead    = (db.milesAirborneDead or 0)
        local airborneMnt     = (db.milesAirborneMounted or 0)
        local travelled       = (walkedTotal + ridden + flown + boatsTotal + swumTotal + airborneTotal)

        local faction = UnitFactionGroup("player")
        local fr, fg, fb = 0, 0.44, 0.87
        if faction == "Horde" then
            fr, fg, fb = 1, 0.12, 0.12
        end

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("My Feet Hurt", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Walking:", FormatDistance(walkedTotal), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("   Alive:", FormatDistance(walkedAlive), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("   Dead:", FormatDistance(walkedDead), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("Riding:", FormatDistance(ridden), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Flight Path:", FormatDistance(flown), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Public Transport:", FormatDistance(boatsTotal), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("   Alive:", FormatDistance(boatsAlive), 0.8, 0.6, 0, 0.8, 0.6, 0)
        GameTooltip:AddDoubleLine("   Dead:", FormatDistance(boatsDead), 0.8, 0.6, 0, 0.8, 0.6, 0)
        GameTooltip:AddDoubleLine("Swimming:", FormatDistance(swumTotal), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("   Unmounted:", FormatDistance(swumUnm), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("      Alive:", FormatDistance(swumUnmAlive), 0.8, 0.6, 0, 0.8, 0.6, 0)
        GameTooltip:AddDoubleLine("      Dead:", FormatDistance(swumUnmDead), 0.8, 0.6, 0, 0.8, 0.6, 0)
        GameTooltip:AddDoubleLine("   Mounted:", FormatDistance(swumMount), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("Airborne:", FormatDistance(airborneTotal), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("   Unmounted:", FormatDistance(airborneUnm), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddDoubleLine("      Alive:", FormatDistance(airborneAlive), 0.8, 0.6, 0, 0.8, 0.6, 0)
        GameTooltip:AddDoubleLine("      Dead:", FormatDistance(airborneDead), 0.8, 0.6, 0, 0.8, 0.6, 0)
        GameTooltip:AddDoubleLine("   Mounted:", FormatDistance(airborneMnt), 0.9, 0.7, 0, 0.9, 0.7, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total Distance Travelled:", FormatDistance(travelled), fr, fg, fb, fr, fg, fb)
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

local lastUpdate = 0
local updateInterval = 0.04  -- High-precision tick rate (~25 updates per second)
local isOnBoatState = false  -- State machine for boat/zeppelin tracking
local boatCandidateTime = 0  -- How long the speed mismatch has been sustained
local uiElapsed = 0          -- Time since the window was last refreshed
local uiDirty = false          -- Set when stats changed since the last window refresh

distanceTracker:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < updateInterval then return end

    if not MyFeetHurtDB then
        InitializeSavedVariables()
    end

    if not InCombatLockdown() then
        local legSpeed = GetUnitSpeed("player") or 0
        local isWalking = legSpeed > 0
        
        local isOnTaxi = UnitOnTaxi("player")
        
        local isFlying = false
        if type(IsFlying) == "function" then isFlying = IsFlying() end
        
        local isSwimming = false
        if type(IsSwimming) == "function" then isSwimming = IsSwimming() end

        local isFallingNative = false
        if type(IsFalling) == "function" then isFallingNative = IsFalling() end

        local currentY, currentX, currentZ = UnitPosition("player")

        if currentY and currentX and currentZ and lastY and lastX and lastZ then
            local dy = currentY - lastY
            local dx = currentX - lastX
            local dz = currentZ - lastZ
            local distanceYards = math.sqrt(dx*dx + dy*dy + dz*dz)
            
            if distanceYards > 0.001 and distanceYards < 150 then
                local distanceMiles = distanceYards * YARDS_TO_MILES
                local actualSpeed = distanceYards / lastUpdate
                
                local isAirborneNow = false
                if not isFlying and not isSwimming and not isOnTaxi then
                    isAirborneNow = isFallingNative
                end

                local speedDiff = math.abs(actualSpeed - legSpeed)
                if isSwimming or isFlying or isOnTaxi or isAirborneNow then
                    isOnBoatState = false
                    boatCandidateTime = 0
                elseif speedDiff > 4.0 then
                    boatCandidateTime = boatCandidateTime + lastUpdate
                    if boatCandidateTime >= CONFIG.BOAT_ENTER_DELAY then
                        isOnBoatState = true
                    end
                else
                    boatCandidateTime = 0
                    if speedDiff < 1.0 then
                        isOnBoatState = false
                    end
                end

                if isOnTaxi then
                    MyFeetHurtDB.milesFlown = (MyFeetHurtDB.milesFlown or 0) + distanceMiles
                    CheckAndNotifyMilestones("flownMilestone", MyFeetHurtDB.milesFlown, "flown", "flying")
                
                elseif isOnBoatState then
                    MyFeetHurtDB.milesBoats = (MyFeetHurtDB.milesBoats or 0) + distanceMiles
                    if UnitIsDeadOrGhost("player") then
                        MyFeetHurtDB.milesBoatsDead = (MyFeetHurtDB.milesBoatsDead or 0) + distanceMiles
                    else
                        MyFeetHurtDB.milesBoatsAlive = (MyFeetHurtDB.milesBoatsAlive or 0) + distanceMiles
                    end
                    CheckAndNotifyMilestones("boatsMilestone", MyFeetHurtDB.milesBoats, "used public transportation", "traveling via public transport")

                    if isWalking then
                        local legDistanceMiles = (legSpeed * lastUpdate) * YARDS_TO_MILES
                        
                        if IsMounted() then
                            MyFeetHurtDB.milesRidden = (MyFeetHurtDB.milesRidden or 0) + legDistanceMiles
                            CheckAndNotifyMilestones("riddenMilestone", MyFeetHurtDB.milesRidden, "ridden", "riding")
                        else
                            MyFeetHurtDB.milesWalked = (MyFeetHurtDB.milesWalked or 0) + legDistanceMiles
                            if UnitIsDeadOrGhost("player") then
                                MyFeetHurtDB.milesWalkedDead = (MyFeetHurtDB.milesWalkedDead or 0) + legDistanceMiles
                            else
                                MyFeetHurtDB.milesWalkedAlive = (MyFeetHurtDB.milesWalkedAlive or 0) + legDistanceMiles
                            end
                            CheckAndNotifyMilestones("walkedMilestone", MyFeetHurtDB.milesWalked, "walked", "walking")
                        end
                    end

                elseif isSwimming then
                    MyFeetHurtDB.milesSwum = (MyFeetHurtDB.milesSwum or 0) + distanceMiles
                    if IsMounted() then
                        MyFeetHurtDB.milesSwumMounted = (MyFeetHurtDB.milesSwumMounted or 0) + distanceMiles
                    else
                        MyFeetHurtDB.milesSwumUnmounted = (MyFeetHurtDB.milesSwumUnmounted or 0) + distanceMiles
                        if UnitIsDeadOrGhost("player") then
                            MyFeetHurtDB.milesSwumUnmountedDead = (MyFeetHurtDB.milesSwumUnmountedDead or 0) + distanceMiles
                        else
                            MyFeetHurtDB.milesSwumUnmountedAlive = (MyFeetHurtDB.milesSwumUnmountedAlive or 0) + distanceMiles
                        end
                    end
                    CheckAndNotifyMilestones("swumMilestone", MyFeetHurtDB.milesSwum, "swum", "swimming")

                elseif isFlying then
                    MyFeetHurtDB.milesFlown = (MyFeetHurtDB.milesFlown or 0) + distanceMiles
                    CheckAndNotifyMilestones("flownMilestone", MyFeetHurtDB.milesFlown, "flown", "flying")

                else
                    if not isAirborneNow then
                        if IsMounted() then
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
                    else
                        MyFeetHurtDB.milesAirborne = (MyFeetHurtDB.milesAirborne or 0) + distanceMiles
                        if UnitIsDeadOrGhost("player") then
                            MyFeetHurtDB.milesAirborneDead = (MyFeetHurtDB.milesAirborneDead or 0) + distanceMiles
                        else
                            MyFeetHurtDB.milesAirborneAlive = (MyFeetHurtDB.milesAirborneAlive or 0) + distanceMiles
                        end
                        if IsMounted() then
                            MyFeetHurtDB.milesAirborneMounted = (MyFeetHurtDB.milesAirborneMounted or 0) + distanceMiles
                        else
                            MyFeetHurtDB.milesAirborneUnmounted = (MyFeetHurtDB.milesAirborneUnmounted or 0) + distanceMiles
                        end
                        CheckAndNotifyMilestones("airborneMilestone", MyFeetHurtDB.milesAirborne, "been airborne", "jumping and falling")
                    end
                end

                local totalBaseMiles = (MyFeetHurtDB.milesWalked or 0) + (MyFeetHurtDB.milesRidden or 0) + (MyFeetHurtDB.milesFlown or 0) + (MyFeetHurtDB.milesBoats or 0) + (MyFeetHurtDB.milesSwum or 0) + (MyFeetHurtDB.milesAirborne or 0)
                CheckAndNotifyMilestones("travelledMilestone", totalBaseMiles, "travelled", "travelling")

                uiDirty = true
            end
        end

        -- Refresh the window at a fixed rate; also covers the last update after you stop moving
        if uiDirty then
            uiElapsed = uiElapsed + lastUpdate
            if uiElapsed >= CONFIG.UI_REFRESH_INTERVAL then
                uiElapsed = 0
                uiDirty = false
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
SlashCmdList["MYFEETHURT"] = function(msg)
    InitializeSavedVariables()

    local command = strlower(strtrim(msg or ""))
    if command == "reset" then
        for key, value in pairs(DEFAULT_DB) do
            MyFeetHurtDB[key] = value
        end
        RecalculateGlobalValues()
        print("|cFFFF0000[MyFeetHurt] All stats and milestones have been reset to 0!|r")
        return
    end

    if not uiCreated or not MyFeetHurtUI then
        CreateMyFeetHurtUI()
    end
    if MyFeetHurtUI:IsShown() then
        MyFeetHurtUI:Hide()
    else
        MyFeetHurtUI:Show()
    end
end