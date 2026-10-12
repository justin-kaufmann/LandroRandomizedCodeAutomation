-- Status panel, code display/copy dialog, and lightweight presentation refresh.
local UI = LLRCA_UI
local L, TEXT = UI.L, UI.TEXT
local GOLD, PALE_GOLD, WHITE = UI.GOLD, UI.PALE_GOLD, UI.WHITE
local MUTED, RED, GREEN = UI.MUTED, UI.RED, UI.GREEN
local ApplyBackdrop, AddLine = UI.ApplyBackdrop, UI.AddLine
local CreateLabel, CreateEditBox, CreateStyledButton = UI.CreateLabel, UI.CreateEditBox, UI.CreateStyledButton
local frame, rightPanel = UI.frame, UI.rightPanel

-- RIGHT: live status and codes
CreateLabel(rightPanel, TEXT.currentStatus, 16, -15, 340, "GameFontNormal", GOLD)
AddLine(rightPanel, 16, -40, 350, 1, 0.48, 0.31, 0.09, 0.9)

local statusDot = rightPanel:CreateTexture(nil, "ARTWORK")
statusDot:SetColorTexture(0.65, 0.57, 0.34, 1)
statusDot:SetSize(9, 9)
statusDot:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 18, -59)

CreateLabel(rightPanel, L.STATUS_LABEL, 36, -56, 72, "GameFontNormalSmall", MUTED)
local statusText = CreateLabel(rightPanel, L.NOT_STARTED, 105, -56, 245, "GameFontHighlight", WHITE)
LLRCA_StatusText = statusText

-- Main logic can update the learning/status message with explicit severity.
function LLRCA_SetLearningStatus(message, kind)
    if not LLRCA_StatusText then return end
    LLRCA_StatusText:SetText(message or "")
    LLRCA_StatusKind = kind or "idle"
    if kind == "error" then
        LLRCA_StatusText:SetTextColor(unpack(RED))
        statusDot:SetColorTexture(0.95, 0.12, 0.10, 1)
    elseif kind == "ready" then
        LLRCA_StatusText:SetTextColor(unpack(GREEN))
        statusDot:SetColorTexture(0.20, 0.85, 0.28, 1)
    elseif kind == "learning" then
        LLRCA_StatusText:SetTextColor(unpack(GOLD))
        statusDot:SetColorTexture(1.00, 0.60, 0.12, 1)
    else
        LLRCA_StatusText:SetTextColor(unpack(WHITE))
        statusDot:SetColorTexture(0.65, 0.57, 0.34, 1)
    end
end

CreateLabel(rightPanel, TEXT.progress, 18, -87, 150, "GameFontNormalSmall", MUTED)
local progressText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
progressText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -18, -87)
progressText:SetWidth(190)
progressText:SetJustifyH("RIGHT")
progressText:SetTextColor(unpack(PALE_GOLD))
progressText:SetText("- / 0")
LLRCA_ProgressText = progressText

local progressBar = CreateFrame("StatusBar", nil, rightPanel, "BackdropTemplate")
progressBar:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 17, -108)
progressBar:SetSize(348, 12)
progressBar:SetMinMaxValues(0, 100)
progressBar:SetValue(0)
progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
progressBar:GetStatusBarTexture():SetVertexColor(0.18, 0.74, 0.27, 1)
ApplyBackdrop(progressBar, 1, { 0.36, 0.29, 0.13, 1 })
progressBar:SetBackdropColor(0.035, 0.03, 0.022, 1)
LLRCA_ProgressBar = progressBar

AddLine(rightPanel, 16, -137, 350, 1, 0.48, 0.31, 0.09, 0.9)
CreateLabel(rightPanel, TEXT.currentCode, 17, -157, 320, "GameFontNormal", PALE_GOLD)

local function CreateCodeValue(y)
    local valueFrame = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    valueFrame:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 14, y)
    valueFrame:SetSize(354, 38)
    ApplyBackdrop(valueFrame, 1, { 0.38, 0.31, 0.19, 1 })
    valueFrame:SetBackdropColor(0.003, 0.003, 0.003, 1)
    local value = valueFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("LEFT", valueFrame, "LEFT", 9, 0)
    value:SetWidth(260)
    value:SetJustifyH("LEFT")
    value:SetWordWrap(false)
    value:SetText("-")
    return valueFrame, value
end

local nextCodeBox, nextCodeText = CreateCodeValue(-179)
LLRCA_NextCodeText = nextCodeText
local nextCopy = CreateStyledButton(nextCodeBox, L.COPY, 76, 25, { 0.29, 0.12, 0.015 })
nextCopy:SetPoint("RIGHT", nextCodeBox, "RIGHT", -6, 0)
nextCopy:Hide()
LLRCA_NextCopyButton = nextCopy

CreateLabel(rightPanel, TEXT.previousCode, 17, -237, 320, "GameFontNormal", PALE_GOLD)
local lastCodeBox, lastCodeText = CreateCodeValue(-259)
LLRCA_LastCodeText = lastCodeText
local lastCopy = CreateStyledButton(lastCodeBox, L.COPY, 76, 25, { 0.29, 0.12, 0.015 })
lastCopy:SetPoint("RIGHT", lastCodeBox, "RIGHT", -6, 0)
lastCopy:Hide()
LLRCA_LastCopyButton = lastCopy

CreateLabel(rightPanel, TEXT.readyHint, 17, -322, 348, "GameFontDisableSmall", MUTED)

-- Footer buttons
local resetButton = CreateStyledButton(frame, L.DEFAULT, 370, 34, { 0.29, 0.025, 0.015 })
resetButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -478)
resetButton:SetScript("OnClick", function()
    if LLRCA_ConfigControlsLocked then return end
    LLRCA_DB.codeCount = LLRCA_DEFAULTS.codeCount
    LLRCA_CountBox:SetNumber(LLRCA_DEFAULTS.codeCount)
    LLRCA_DB.codeLength = LLRCA_DEFAULTS.codeLength
    LLRCA_LengthBox:SetNumber(LLRCA_DEFAULTS.codeLength)
    wipe(LLRCA_DB.path)
    table.insert(LLRCA_DB.path, LLRCA_DB.rootMenuOption or "")
    for index = 2, #LLRCA_DEFAULTS.path do
        table.insert(LLRCA_DB.path, LLRCA_DEFAULTS.path[index])
    end
    LLRCA_RefreshPathRows()
end)
LLRCA_ResetButton = resetButton
LLRCA_SetConfigControlsLocked(LLRCA_ConfigControlsLocked)

local startButton = CreateStyledButton(frame, L.START, 370, 34, { 0.10, 0.34, 0.10 })
startButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -478)
LLRCA_StartButton = startButton

CreateLabel(frame, L.FOOTER_TAGLINE, 18, -526, 440, "GameFontDisableSmall", MUTED)
local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
versionText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -526)
versionText:SetWidth(100)
versionText:SetJustifyH("RIGHT")
versionText:SetTextColor(unpack(MUTED))
versionText:SetText("v3.0.0")

-- Copy dialog, restyled to match the main window.
local copyFrame = CreateFrame("Frame", "LLRCA_CopyFrame", UIParent, "BackdropTemplate")
copyFrame:SetSize(500, 150)
copyFrame:SetPoint("CENTER")
copyFrame:SetFrameStrata("DIALOG")
copyFrame:SetClampedToScreen(true)
ApplyBackdrop(copyFrame, 0.99, { 0.86, 0.56, 0.13, 1 })
copyFrame:Hide()
LLRCA_CopyFrame = copyFrame
table.insert(UISpecialFrames, "LLRCA_CopyFrame")

CreateLabel(copyFrame, L.COPY_TITLE, 18, -16, 440, "GameFontNormalLarge", GOLD)
AddLine(copyFrame, 18, -43, 464, 1, 0.48, 0.31, 0.09, 0.9)

local copyEdit = CreateEditBox(copyFrame, 460, 30, "")
copyEdit:SetPoint("TOPLEFT", copyFrame, "TOPLEFT", 20, -55)
LLRCA_CopyEdit = copyEdit
copyEdit:SetScript("OnEscapePressed", function()
    copyEdit:SetText("")
    copyFrame:Hide()
end)
copyEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

local closeCopy = CreateStyledButton(copyFrame, TEXT.close, 120, 26, { 0.29, 0.12, 0.015 })
closeCopy:SetPoint("BOTTOM", copyFrame, "BOTTOM", 0, 12)
closeCopy:SetScript("OnClick", function()
    copyEdit:SetText("")
    copyFrame:Hide()
end)

nextCopy:SetScript("OnClick", function()
    if not LLRCA_CurrentCode then return end
    copyEdit:SetText(LLRCA_CurrentCode)
    copyFrame:Show()
    copyFrame:Raise()
    copyEdit:SetFocus()
    copyEdit:HighlightText()
end)

lastCopy:SetScript("OnClick", function()
    if not LLRCA_PreviousCode then return end
    copyEdit:SetText(LLRCA_PreviousCode)
    copyFrame:Show()
    copyFrame:Raise()
    copyEdit:SetFocus()
    copyEdit:HighlightText()
end)

-- The existing automation logic updates the public progress text. Poll it at a
-- low frequency to drive the visual bar without changing the automation logic.
local uiRefreshElapsed = 0
local lastProgressKey = nil
local lastStartText = nil
frame:SetScript("OnUpdate", function(self, elapsed)
    uiRefreshElapsed = uiRefreshElapsed + elapsed
    if uiRefreshElapsed < 0.15 then return end
    uiRefreshElapsed = 0

    if LLRCA_ProgressText and LLRCA_ProgressBar then
        local text = LLRCA_ProgressText:GetText() or ""
        local current, total = text:match("(%d+)%s*/%s*(%d+)")
        if current and total and tonumber(total) > 0 then
            current, total = tonumber(current), tonumber(total)
            local key = tostring(current) .. "/" .. tostring(total)
            if key ~= lastProgressKey then
                LLRCA_ProgressBar:SetMinMaxValues(0, total)
                LLRCA_ProgressBar:SetValue(math.min(current, total))
                lastProgressKey = key
            end
        elseif lastProgressKey ~= "0/0" then
            LLRCA_ProgressBar:SetMinMaxValues(0, 100)
            LLRCA_ProgressBar:SetValue(0)
            lastProgressKey = "0/0"
        end
    end

    if LLRCA_StatusText then
        local status = string.lower(tostring(LLRCA_StatusText:GetText() or ""))
        if LLRCA_StatusKind == "error" then
            statusDot:SetColorTexture(0.95, 0.12, 0.10, 1)
        elseif LLRCA_StatusKind == "ready" then
            statusDot:SetColorTexture(0.20, 0.85, 0.28, 1)
        elseif LLRCA_StatusKind == "learning" then
            statusDot:SetColorTexture(1.00, 0.60, 0.12, 1)
        elseif status:find("wait", 1, true) or status:find("abwarten", 1, true) then
            statusDot:SetColorTexture(0.25, 0.62, 1.00, 1)
        elseif status:find("talk", 1, true) or status:find("landro", 1, true) then
            statusDot:SetColorTexture(1.00, 0.60, 0.12, 1)
        elseif status:find("finish", 1, true) or status:find("fertig", 1, true) then
            statusDot:SetColorTexture(0.20, 0.85, 0.28, 1)
        elseif status:find("stop", 1, true) or status:find("gestoppt", 1, true) then
            statusDot:SetColorTexture(0.85, 0.18, 0.12, 1)
        else
            statusDot:SetColorTexture(0.65, 0.57, 0.34, 1)
        end
    end

    if LLRCA_StartButton then
        local fs = LLRCA_StartButton:GetFontString()
        local label = fs and fs:GetText() or ""
        local isStop = label == L.STOP
        local canStart = LLRCA_CanStartAutomation and LLRCA_CanStartAutomation() or false
        local enabled = isStop or canStart
        LLRCA_StartButton:SetEnabled(enabled)
        LLRCA_StartButton:SetAlpha(enabled and 1 or 0.45)
        if label ~= lastStartText then
            if label == L.STOP then
                local n = LLRCA_StartButton:GetNormalTexture()
                local p = LLRCA_StartButton:GetPushedTexture()
                if n then n:SetVertexColor(0.42, 0.035, 0.025, 1) end
                if p then p:SetVertexColor(0.28, 0.02, 0.015, 1) end
            else
                local n = LLRCA_StartButton:GetNormalTexture()
                local p = LLRCA_StartButton:GetPushedTexture()
                if n then n:SetVertexColor(0.08, 0.32, 0.09, 1) end
                if p then p:SetVertexColor(0.05, 0.22, 0.06, 1) end
            end
            lastStartText = label
        end
    end
end)
