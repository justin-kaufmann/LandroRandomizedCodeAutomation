-- Landro Longshot Randomized Code Automation
-- Compact, dark/gold two-column UI refresh. Keeps the public widget globals
-- expected by LandroRandomizedCodeAutomation.lua.

local isGerman = GetLocale() == "deDE"
local L = LLRCA_L or {}

local TEXT = {
    configuration = L.FRAME_CONFIGURATION,
    codeCount = L.FRAME_CODE_COUNT,
    codeLength = L.FRAME_CODE_LENGTH,
    menuPath = L.FRAME_MENU_PATH,
    menuHint = L.FRAME_MENU_HINT,
    addStep = L.ADD_STEP,
    removeStep = L.REMOVE_STEP,
    selectOption = L.SELECT_OPTION,
    noOptions = L.NO_OPTIONS_LEARNED,
    selectPrevious = L.SELECT_PREVIOUS_STEP,
    learnBranch = L.LEARN_CHILD_OPTIONS,
    learnRootTalk = L.LEARN_ROOT_TALK,
    learnRootOptions = L.LEARN_ROOT_OPTIONS,
    optionsReady = L.OPTIONS_READY,
    noFollowUps = L.NO_FOLLOW_UPS,
    pathLimit = L.PATH_LIMIT,
    currentStatus = L.FRAME_CURRENT_STATUS,
    progress = L.FRAME_PROGRESS,
    currentCode = L.FRAME_CURRENT_CODE,
    previousCode = L.FRAME_PREVIOUS_CODE,
    luaAddon = L.FRAME_ADDON_BADGE,
    entry = L.FRAME_PATH_ENTRY_PREFIX,
    rootEntry = L.ROOT_ENTRY,
    rootWaiting = L.ROOT_WAITING,
    close = L.CLOSE,
    readyHint = L.FRAME_READY_HINT,
}

local GOLD = { 1.00, 0.78, 0.18, 1 }
local PALE_GOLD = { 1.00, 0.88, 0.48, 1 }
local WHITE = { 0.93, 0.93, 0.91, 1 }
local MUTED = { 0.68, 0.65, 0.58, 1 }
local RED = { 1.00, 0.25, 0.20, 1 }
local GREEN = { 0.35, 1.00, 0.48, 1 }

local function ApplyBackdrop(target, backgroundAlpha, borderColor)
    target:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    target:SetBackdropColor(0.012, 0.010, 0.008, backgroundAlpha or 0.97)
    local c = borderColor or { 0.68, 0.43, 0.10, 0.95 }
    target:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
end

local function AddLine(parent, x, y, width, height, r, g, b, a, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetColorTexture(r or 0.62, g or 0.39, b or 0.10, a or 0.85)
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    texture:SetSize(width, height or 1)
    return texture
end

local function CreateLabel(parent, text, x, y, width, font, color, justify)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then label:SetWidth(width) end
    label:SetJustifyH(justify or "LEFT")
    label:SetTextColor(unpack(color or GOLD))
    label:SetText(text or "")
    return label
end

local function CreatePanel(parent, x, y, width, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    panel:SetSize(width, height)
    ApplyBackdrop(panel, 0.94, { 0.40, 0.27, 0.09, 0.90 })
    return panel
end

local function CreateEditBox(parent, width, height, initialText)
    local edit = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    edit:SetSize(width, height)
    ApplyBackdrop(edit, 1, { 0.40, 0.37, 0.31, 0.95 })
    edit:SetBackdropColor(0.004, 0.004, 0.004, 1)
    edit:SetFontObject("GameFontHighlight")
    edit:SetTextColor(0.96, 0.94, 0.87, 1)
    edit:SetTextInsets(8, 8, 2, 2)
    edit:SetJustifyH("LEFT")
    edit:SetAutoFocus(false)
    edit:SetText(initialText or "")
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(1.00, 0.72, 0.16, 1)
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(0.40, 0.37, 0.31, 0.95)
    end)
    return edit
end

local function StyleButton(button, color)
    local normal = "Interface\\Buttons\\WHITE8X8"
    button:SetNormalTexture(normal)
    button:SetPushedTexture(normal)
    button:SetHighlightTexture(normal)
    local n = button:GetNormalTexture()
    if n then n:SetVertexColor(color[1], color[2], color[3], 1) end
    local p = button:GetPushedTexture()
    if p then p:SetVertexColor(color[1] * 0.72, color[2] * 0.72, color[3] * 0.72, 1) end
    local h = button:GetHighlightTexture()
    if h then h:SetVertexColor(1, 0.86, 0.52, 0.20) end

    -- Add a thin gold outline because the flat fill replaces the template's
    -- original button artwork.
    local borderColor = { 0.78, 0.49, 0.13, 1 }
    AddLine(button, 0, 0, button:GetWidth(), 1, borderColor[1], borderColor[2], borderColor[3], borderColor[4], "OVERLAY")
    AddLine(button, 0, -button:GetHeight() + 1, button:GetWidth(), 1, borderColor[1], borderColor[2], borderColor[3], borderColor[4], "OVERLAY")
    AddLine(button, 0, 0, 1, button:GetHeight(), borderColor[1], borderColor[2], borderColor[3], borderColor[4], "OVERLAY")
    local rightEdge = button:CreateTexture(nil, "OVERLAY")
    rightEdge:SetColorTexture(unpack(borderColor))
    rightEdge:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    rightEdge:SetSize(1, button:GetHeight())

    local fs = button:GetFontString()
    if fs then
        fs:SetTextColor(1.00, 0.90, 0.64, 1)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    end
end

local function CreateStyledButton(parent, text, width, height, color)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text or "")
    StyleButton(button, color or { 0.28, 0.035, 0.02 })
    return button
end

-- Main window: deliberately does not use BasicFrameTemplateWithInset because
-- its default layout created the very tall, single-column window in the screenshot.
local frame = CreateFrame("Frame", "LLRCA_MainFrame", UIParent, "BackdropTemplate")
frame:SetSize(800, 560)
ApplyBackdrop(frame, 0.985, { 0.86, 0.56, 0.13, 1 })
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetPoint(
    (LLRCA_DB and LLRCA_DB.framePos and LLRCA_DB.framePos.point) or "CENTER",
    UIParent,
    (LLRCA_DB and LLRCA_DB.framePos and LLRCA_DB.framePos.relativePoint) or "CENTER",
    (LLRCA_DB and LLRCA_DB.framePos and LLRCA_DB.framePos.x) or 0,
    (LLRCA_DB and LLRCA_DB.framePos and LLRCA_DB.framePos.y) or 0
)
frame:Hide()
LLRCA_Frame = frame

table.insert(UISpecialFrames, "LLRCA_MainFrame")

frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    LLRCA_DB.framePos = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 0,
    }
end)

-- Header
local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
header:SetHeight(57)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() frame:StartMoving() end)
header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    LLRCA_DB.framePos = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 0,
    }
end)

local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints(header)
headerBg:SetColorTexture(0.025, 0.018, 0.009, 0.98)

-- Add a small in-game icon beside the title, as in the visual reference.
local titleIcon = CreateFrame("Frame", nil, header, "BackdropTemplate")
titleIcon:SetSize(36, 36)
titleIcon:SetPoint("TOPLEFT", header, "TOPLEFT", 12, -8)
ApplyBackdrop(titleIcon, 1, { 0.78, 0.49, 0.13, 1 })
local titleIconTexture = titleIcon:CreateTexture(nil, "ARTWORK")
titleIconTexture:SetPoint("TOPLEFT", titleIcon, "TOPLEFT", 3, -3)
titleIconTexture:SetPoint("BOTTOMRIGHT", titleIcon, "BOTTOMRIGHT", -3, 3)
titleIconTexture:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
titleIconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

CreateLabel(header, L.MAIN_TITLE, 56, -8, 500, "GameFontNormalLarge", GOLD)
CreateLabel(header, string.upper(L.HEADER_TAGLINE), 58, -32, 500, "GameFontNormalSmall", PALE_GOLD)
local addonBadge = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
addonBadge:SetPoint("TOPRIGHT", header, "TOPRIGHT", -44, -22)
addonBadge:SetWidth(245)
addonBadge:SetJustifyH("RIGHT")
addonBadge:SetTextColor(unpack(MUTED))
addonBadge:SetText(TEXT.luaAddon)
AddLine(frame, 18, -62, 764, 2, 0.78, 0.47, 0.10, 0.95)

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetSize(28, 28)
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -4)
closeButton:SetScript("OnClick", function() frame:Hide() end)

-- Two-column body
local leftPanel = CreatePanel(frame, 16, -74, 374, 390)
local rightPanel = CreatePanel(frame, 402, -74, 382, 390)


-- Shared UI references used by the smaller UI modules loaded after this file.
LLRCA_UI = LLRCA_UI or {}
local UI = LLRCA_UI
UI.isGerman = isGerman
UI.L = L
UI.TEXT = TEXT
UI.GOLD = GOLD
UI.PALE_GOLD = PALE_GOLD
UI.WHITE = WHITE
UI.MUTED = MUTED
UI.RED = RED
UI.GREEN = GREEN
UI.ApplyBackdrop = ApplyBackdrop
UI.AddLine = AddLine
UI.CreateLabel = CreateLabel
UI.CreatePanel = CreatePanel
UI.CreateEditBox = CreateEditBox
UI.StyleButton = StyleButton
UI.CreateStyledButton = CreateStyledButton
UI.frame = frame
UI.leftPanel = leftPanel
UI.rightPanel = rightPanel
