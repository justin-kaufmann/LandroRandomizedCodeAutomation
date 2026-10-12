-- Menu-path selector and dynamic hierarchical route rows.
local UI = LLRCA_UI
local L, TEXT = UI.L, UI.TEXT
local GOLD, PALE_GOLD, WHITE = UI.GOLD, UI.PALE_GOLD, UI.WHITE
local MUTED, RED, GREEN = UI.MUTED, UI.RED, UI.GREEN
local ApplyBackdrop, AddLine = UI.ApplyBackdrop, UI.AddLine
local CreateLabel, CreatePanel = UI.CreateLabel, UI.CreatePanel
local CreateEditBox, CreateStyledButton = UI.CreateEditBox, UI.CreateStyledButton
local frame, leftPanel, rightPanel = UI.frame, UI.leftPanel, UI.rightPanel

-- LEFT: configuration
CreateLabel(leftPanel, TEXT.configuration, 16, -15, 330, "GameFontNormal", GOLD)
AddLine(leftPanel, 16, -40, 342, 1, 0.48, 0.31, 0.09, 0.9)

CreateLabel(leftPanel, L.CODES, 16, -60, 205, "GameFontNormal", PALE_GOLD)
local countBox = CreateEditBox(leftPanel, 108, 26, tostring(LLRCA_DB.codeCount or LLRCA_DEFAULTS.codeCount))
countBox:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -16, -53)
countBox:SetNumeric(true)
countBox:SetMaxLetters(5)
countBox:SetScript("OnEditFocusLost", function(self)
    local value = tonumber(self:GetText()) or LLRCA_DEFAULTS.codeCount
    value = math.floor(value)
    if value < 1 then value = 1 elseif value > 10000 then value = 10000 end
    LLRCA_DB.codeCount = value
    self:SetNumber(value)
    self:ClearFocus()
    self:SetBackdropBorderColor(0.40, 0.37, 0.31, 0.95)
end)
LLRCA_CountBox = countBox

CreateLabel(leftPanel, L.CODE_LENGTH, 16, -99, 205, "GameFontNormal", PALE_GOLD)
local lengthBox = CreateEditBox(leftPanel, 108, 26, tostring(LLRCA_DB.codeLength or LLRCA_DEFAULTS.codeLength))
lengthBox:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -16, -92)
lengthBox:SetNumeric(true)
lengthBox:SetMaxLetters(2)
lengthBox:SetScript("OnEditFocusLost", function(self)
    local value = tonumber(self:GetText()) or LLRCA_DEFAULTS.codeLength
    value = math.floor(value)
    if value < 5 then value = 5 elseif value > 50 then value = 50 end
    LLRCA_DB.codeLength = value
    self:SetNumber(value)
    self:ClearFocus()
    self:SetBackdropBorderColor(0.40, 0.37, 0.31, 0.95)
end)
LLRCA_LengthBox = lengthBox

AddLine(leftPanel, 16, -132, 342, 1, 0.48, 0.31, 0.09, 0.9)
CreateLabel(leftPanel, TEXT.menuPath, 16, -151, 342, "GameFontNormal", GOLD)
CreateLabel(leftPanel, TEXT.menuHint, 16, -173, 342, "GameFontDisableSmall", MUTED)

-- NPC menu path: dropdown-only rows populated from real gossip options.
-- Rows are created on demand. There is no arbitrary maximum route depth.
local PATH_ROW_HEIGHT = 30
local pathRows = {}
local activePathIndex = nil
local activeDropdownButton = nil

local pathScroll = CreateFrame("ScrollFrame", "LLRCA_PathScroll", leftPanel, "UIPanelScrollFrameTemplate")
pathScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 12, -194)
pathScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -24, 40)
pathScroll:EnableMouseWheel(true)

local pathContent = CreateFrame("Frame", nil, pathScroll)
pathContent:SetSize(310, 1)
pathScroll:SetScrollChild(pathContent)
pathScroll:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll() or 0
    local maxScroll = math.max(0, pathContent:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, current - delta * PATH_ROW_HEIGHT)))
end)

local pathPopup = CreateFrame("Frame", "LLRCA_PathDropdownPopup", UIParent, "BackdropTemplate")
-- Use a dedicated high strata so the menu cannot be hidden behind the main
-- addon's scroll-frame buttons or other controls.
pathPopup:SetFrameStrata("FULLSCREEN_DIALOG")
pathPopup:SetFrameLevel(math.max(UIParent:GetFrameLevel() + 100, frame:GetFrameLevel() + 100))
pathPopup:SetClampedToScreen(true)
pathPopup:SetSize(300, 190)
ApplyBackdrop(pathPopup, 0.995, { 0.96, 0.66, 0.16, 1 })
pathPopup:EnableKeyboard(true)
pathPopup:SetPropagateKeyboardInput(false)
pathPopup:Hide()

local popupHeader = CreateFrame("Frame", nil, pathPopup)
popupHeader:SetPoint("TOPLEFT", pathPopup, "TOPLEFT", 5, -5)
popupHeader:SetPoint("TOPRIGHT", pathPopup, "TOPRIGHT", -5, -5)
popupHeader:SetHeight(27)
local popupTitle = popupHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
popupTitle:SetPoint("LEFT", popupHeader, "LEFT", 7, 0)
popupTitle:SetTextColor(unpack(PALE_GOLD))
popupTitle:SetText(TEXT.selectOption)
local popupClose = CreateFrame("Button", nil, popupHeader, "UIPanelCloseButton")
popupClose:SetSize(22, 22)
popupClose:SetPoint("RIGHT", popupHeader, "RIGHT", 1, 0)
popupClose:SetFrameLevel(pathPopup:GetFrameLevel() + 20)

local popupHeaderLine = popupHeader:CreateTexture(nil, "ARTWORK")
popupHeaderLine:SetColorTexture(0.60, 0.39, 0.10, 0.9)
popupHeaderLine:SetPoint("BOTTOMLEFT", popupHeader, "BOTTOMLEFT", 2, 0)
popupHeaderLine:SetPoint("BOTTOMRIGHT", popupHeader, "BOTTOMRIGHT", -2, 0)
popupHeaderLine:SetHeight(1)

local popupScroll = CreateFrame("ScrollFrame", nil, pathPopup, "UIPanelScrollFrameTemplate")
popupScroll:SetPoint("TOPLEFT", pathPopup, "TOPLEFT", 7, -34)
popupScroll:SetPoint("BOTTOMRIGHT", pathPopup, "BOTTOMRIGHT", -28, 7)
popupScroll:SetFrameLevel(pathPopup:GetFrameLevel() + 2)
local popupContent = CreateFrame("Frame", nil, popupScroll)
popupContent:SetSize(255, 1)
popupScroll:SetScrollChild(popupContent)
local popupButtons = {}
local popupInfo

local function GetAvailableMenuOptions(index)
    -- Only immediate children of the already-selected parent chain are valid.
    -- Never fall back to the old flat option list: that would reintroduce invalid paths.
    if not LLRCA_GetMenuOptionsForStep then return {} end
    local source = LLRCA_GetMenuOptionsForStep(index) or {}
    local result, seen = {}, {}
    for _, value in ipairs(source) do
        if type(value) == "string" then
            value = LLRCA_NormalizeMenuText(value)
            local key = string.lower(value)
            local ignored = LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(value)
            if value ~= "" and not ignored and not seen[key] then
                seen[key] = true
                table.insert(result, value)
            end
        end
    end
    return result
end

local function HasCompleteParentPath(index)
    local path = LLRCA_DB.path or {}
    for parentIndex = 1, index - 1 do
        if LLRCA_NormalizeMenuText(path[parentIndex]) == "" then return false end
    end
    return true
end

local function IsOptionInList(options, value)
    local wanted = string.lower(LLRCA_NormalizeMenuText(value))
    if wanted == "" then return false end
    for _, option in ipairs(options or {}) do
        if string.lower(LLRCA_NormalizeMenuText(option)) == wanted then return true end
    end
    return false
end

local function IsMenuBranchLearned(index)
    if LLRCA_IsMenuBranchLearnedForStep then
        return LLRCA_IsMenuBranchLearnedForStep(index)
    end
    return #GetAvailableMenuOptions(index) > 0
end

local function IsConfirmedEndpointKey(key)
    if not key or type(LLRCA_DB.knownCodeEndpoints) ~= "table" or LLRCA_DB.knownCodeEndpoints[key] ~= true then
        return false
    end
    -- A real learned child branch takes precedence over an old endpoint flag.
    -- The same exact context cannot simultaneously be a terminal leaf and a menu.
    local branch = (LLRCA_DB.knownMenuTree or {})[key]
    for _, value in ipairs(type(branch) == "table" and branch or {}) do
        local name = LLRCA_NormalizeMenuText(value)
        if name ~= "" and not (LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(name)) then
            LLRCA_DB.knownCodeEndpoints[key] = nil
            return false
        end
    end
    return true
end

local function GetPathPlaceholder(index)
    -- A confirmed code endpoint is terminal regardless of stale child options
    -- persisted by older versions. Keep the next row informative and disabled.
    if index > 2 then
        local endpointKey = LLRCA_MenuContextKey and LLRCA_MenuContextKey(LLRCA_DB.path or {}, index - 1)
        if IsConfirmedEndpointKey(endpointKey) then
            return TEXT.noFollowUps
        end
    end
    if index == 2 then
        if not LLRCA_DB.rootMenuOption or LLRCA_NormalizeMenuText(LLRCA_DB.rootMenuOption) == "" then
            return TEXT.learnRootTalk
        end
        if not IsMenuBranchLearned(index) or #GetAvailableMenuOptions(index) == 0 then
            return TEXT.learnRootOptions
        end
    end
    if not HasCompleteParentPath(index) then return TEXT.selectPrevious end
    if not IsMenuBranchLearned(index) then return TEXT.learnBranch end
    -- A cached empty branch is not an endpoint. Only a confirmed code popup
    -- can make the parent route terminal; otherwise the child needs learning.
    if #GetAvailableMenuOptions(index) == 0 then return TEXT.learnBranch end
    return TEXT.selectOption
end

local function ClosePathPopup()
    activePathIndex = nil
    activeDropdownButton = nil
    pathPopup:Hide()
end

popupClose:SetScript("OnClick", ClosePathPopup)
pathPopup:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        ClosePathPopup()
    end
end)
pathPopup:SetScript("OnHide", function()
    activePathIndex = nil
    activeDropdownButton = nil
end)
-- Never leave the selector floating after its parent addon window is hidden.
frame:HookScript("OnHide", function()
    ClosePathPopup()
end)

local function SelectPathOption(value)
    if not activePathIndex or activePathIndex <= 1 or not value or LLRCA_ConfigControlsLocked then return end
    local selectedIndex = activePathIndex
    value = LLRCA_NormalizeMenuText(value)
    -- Selecting a row is always an explicit learning request, even when the
    -- same label is selected again to retry navigation. Any descendants are
    -- invalidated and the core re-evaluates the live Gossip context.
    LLRCA_DB.path[selectedIndex] = value
    for index = #LLRCA_DB.path, selectedIndex + 1, -1 do
        LLRCA_DB.path[index] = nil
    end
    ClosePathPopup()
    if LLRCA_RefreshPathRows then LLRCA_RefreshPathRows() end
    if LLRCA_RequestLearnPath then LLRCA_RequestLearnPath(selectedIndex) end
end

local function ShowPathPopup(index, dropdown)
    -- path[1] is the fixed start entry; it must never open a selector.
    if not index or index <= 1 then return end
    if pathPopup:IsShown() and activeDropdownButton == dropdown then
        ClosePathPopup()
        return
    end

    activePathIndex = index
    activeDropdownButton = dropdown
    for _, button in ipairs(popupButtons) do button:Hide() end

    local options = GetAvailableMenuOptions(index)
    local rowHeight = 24
    -- Reserve space for the popup title and close button; scroll only the list.
    local desiredHeight = math.min(235, math.max(82, #options * rowHeight + 43))
    pathPopup:SetHeight(desiredHeight)
    popupScroll:SetVerticalScroll(0)

    if #options == 0 then
        if not popupInfo then
            popupInfo = popupContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            popupInfo:SetPoint("TOPLEFT", popupContent, "TOPLEFT", 6, -6)
            popupInfo:SetWidth(220)
            popupInfo:SetJustifyH("LEFT")
        end
        popupInfo:SetText(HasCompleteParentPath(index) and TEXT.learnBranch or TEXT.selectPrevious)
        popupInfo:Show()
        popupInfo:SetPoint("TOPLEFT", popupContent, "TOPLEFT", 6, -6)
        popupContent:SetSize(255, 42)
    else
        if popupInfo then popupInfo:Hide() end
        popupContent:SetSize(255, #options * rowHeight)

        for i, optionName in ipairs(options) do
            local button = popupButtons[i]
            if not button then
                button = CreateFrame("Button", nil, popupContent, "BackdropTemplate")
                button:SetHeight(rowHeight)
                ApplyBackdrop(button, 0.98, { 0.36, 0.28, 0.13, 0.65 })
                button:SetBackdropColor(0.018, 0.015, 0.010, 1)
                button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                button.label:SetPoint("LEFT", button, "LEFT", 7, 0)
                button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
                button.label:SetJustifyH("LEFT")
                button.label:SetWordWrap(false)
                button:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(0.18, 0.11, 0.035, 1)
                    self.label:SetTextColor(1, 0.88, 0.48, 1)
                end)
                button:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(0.018, 0.015, 0.010, 1)
                    self.label:SetTextColor(0.96, 0.94, 0.87, 1)
                end)
                table.insert(popupButtons, button)
            end
            local selectedOption = optionName -- Avoid Lua 5.1 loop-closure capture issues.
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", popupContent, "TOPLEFT", 0, -((i - 1) * rowHeight))
            button:SetPoint("RIGHT", popupContent, "RIGHT", -2, 0)
            button:SetFrameLevel(pathPopup:GetFrameLevel() + 5)
            button.label:SetText(selectedOption)
            button:SetScript("OnClick", function() SelectPathOption(selectedOption) end)
            button:Show()
        end
    end

    pathPopup:ClearAllPoints()
    pathPopup:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    pathPopup:Show()
    pathPopup:Raise()
    -- Keep child widgets in front as well when reopening an existing popup.
    popupHeader:SetFrameLevel(pathPopup:GetFrameLevel() + 1)
    popupScroll:SetFrameLevel(pathPopup:GetFrameLevel() + 2)
    popupClose:SetFrameLevel(pathPopup:GetFrameLevel() + 20)
    for _, button in ipairs(popupButtons) do
        if button:IsShown() then button:SetFrameLevel(pathPopup:GetFrameLevel() + 5) end
    end
end

local function CreatePathRow(index)
    local row = CreateFrame("Frame", nil, pathContent)
    row:SetSize(330, PATH_ROW_HEIGHT)

    local labelText = index == 1 and TEXT.rootEntry or (TEXT.entry .. index)
    local label = CreateLabel(row, labelText, 0, 0, 58, "GameFontNormalSmall", index == 1 and MUTED or PALE_GOLD)
    label:ClearAllPoints()
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(58)
    label:SetJustifyH("LEFT")
    row.label = label

    local dropdown = CreateFrame("Button", nil, row, "BackdropTemplate")
    dropdown:SetSize(270, 25)
    dropdown:SetPoint("LEFT", row, "LEFT", 60, 0)
    ApplyBackdrop(dropdown, 1, index == 1 and { 0.27, 0.26, 0.23, 0.9 } or { 0.40, 0.37, 0.31, 0.95 })
    dropdown:SetBackdropColor(index == 1 and 0.035 or 0.004, index == 1 and 0.032 or 0.004, index == 1 and 0.028 or 0.004, 1)

    local valueText = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    valueText:SetPoint("RIGHT", dropdown, "RIGHT", index == 1 and -8 or -20, 0)
    valueText:SetJustifyH("LEFT")
    valueText:SetWordWrap(false)
    valueText:SetTextColor(unpack(index == 1 and MUTED or WHITE))
    dropdown.valueText = valueText

    local arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -7, 0)
    arrow:SetText("v")
    arrow:SetTextColor(unpack(GOLD))
    dropdown.arrow = arrow

    if index == 1 then
        -- The root menu choice is detected from Landro's actual initial gossip
        -- menu. It is shown read-only/greyed out and always remains path[1].
        dropdown:Disable()
        dropdown:EnableMouse(false)
        dropdown:SetScript("OnEnter", nil)
        dropdown:SetScript("OnLeave", nil)
        dropdown:SetScript("OnClick", nil)
        arrow:Hide()
    else
        dropdown:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1.00, 0.72, 0.16, 1)
        end)
        dropdown:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.40, 0.37, 0.31, 0.95)
        end)
        dropdown:SetScript("OnClick", function(self) ShowPathPopup(row.index, self) end)
    end
    row.dropdown = dropdown
    return row
end

-- Path depth is managed automatically from the selected route and learned
-- branch/end-point data. The old manual +Step / Remove buttons are intentionally
-- removed from the interface.
LLRCA_ConfigControlsLocked = false
function LLRCA_SetConfigControlsLocked(locked)
    LLRCA_ConfigControlsLocked = locked and true or false
    if LLRCA_ResetButton then
        LLRCA_ResetButton:SetEnabled(not LLRCA_ConfigControlsLocked)
        LLRCA_ResetButton:SetAlpha(not LLRCA_ConfigControlsLocked and 1 or 0.45)
    end
end

local function IsKnownTerminalAt(index)
    if not index or index < 2 then return false end
    local path = LLRCA_DB.path or {}
    local key = LLRCA_MenuContextKey and LLRCA_MenuContextKey(path, index)
    if not key then return false end
    if IsConfirmedEndpointKey(key) then
        return true
    end
    -- Do not infer terminal routes from an empty menu tree entry. Older
    -- versions could create an empty branch before the code popup appeared.
    return false
end

local function NormalizeDynamicPathLength()
    local path = LLRCA_DB.path
    if type(path) ~= "table" then path = {}; LLRCA_DB.path = path end
    if #path < 1 then path[1] = LLRCA_DB.rootMenuOption or "" end
    if LLRCA_DB.rootMenuOption and LLRCA_DB.rootMenuOption ~= "" then path[1] = LLRCA_DB.rootMenuOption end

    -- Keep only the contiguous configured route. There is always a visible
    -- selector for step 2; later rows exist only as the next potential step.
    local lastSelected = 1
    for index = 2, #path do
        if LLRCA_NormalizeMenuText(path[index]) == "" then break end
        lastSelected = index
    end
    local targetLength
    if lastSelected >= 2 and IsKnownTerminalAt(lastSelected) then
        targetLength = lastSelected
    else
        targetLength = lastSelected + 1
    end
    if targetLength < 2 then targetLength = 2 end
    for index = #path, targetLength + 1, -1 do path[index] = nil end
    while #path < targetLength do path[#path + 1] = "" end
end

function LLRCA_RefreshPathRows()
    if type(LLRCA_DB.path) ~= "table" then LLRCA_DB.path = { "" } end
    if #LLRCA_DB.path < 1 then LLRCA_DB.path[1] = "" end
    if LLRCA_DB.rootMenuOption and LLRCA_DB.rootMenuOption ~= "" then
        LLRCA_DB.path[1] = LLRCA_DB.rootMenuOption
    end
    NormalizeDynamicPathLength()

    -- Validate each saved choice against the options belonging to its exact
    -- parent chain. If a parent changed, invalidate that step and all children.
    for index = 2, #LLRCA_DB.path do
        local selected = LLRCA_NormalizeMenuText(LLRCA_DB.path[index])
        if selected ~= "" then
            local available = GetAvailableMenuOptions(index)
            local branchLearned = IsMenuBranchLearned(index)
            -- Do not erase a user's saved choice merely because its parent
            -- branch has not been learned yet (e.g. the fixed start option was
            -- just detected and its child dialog has not opened). Validate and
            -- clear stale choices only after that exact branch is known.
            if branchLearned and not IsOptionInList(available, selected) then
                for clearIndex = index, #LLRCA_DB.path do LLRCA_DB.path[clearIndex] = "" end
                break
            end
        else
            for later = index + 1, #LLRCA_DB.path do
                if LLRCA_NormalizeMenuText(LLRCA_DB.path[later]) ~= "" then
                    for clearIndex = index + 1, #LLRCA_DB.path do LLRCA_DB.path[clearIndex] = "" end
                    break
                end
            end
        end
    end
    -- Validation can invalidate a previously selected branch; collapse any
    -- now-obsolete descendants and keep exactly one next-step placeholder.
    NormalizeDynamicPathLength()

    for _, row in ipairs(pathRows) do row:Hide() end
    for index = 1, #LLRCA_DB.path do
        local row = pathRows[index]
        if not row then
            row = CreatePathRow(index)
            pathRows[index] = row
        end
        row.index = index
        row.label:SetText(index == 1 and TEXT.rootEntry or (TEXT.entry .. index))
        local selected = index == 1 and LLRCA_DB.rootMenuOption or LLRCA_DB.path[index]
        local dropdown = row.dropdown

        if index == 1 then
            dropdown.valueText:SetText(type(selected) == "string" and selected ~= "" and selected or TEXT.rootWaiting)
            dropdown.valueText:SetTextColor(unpack(MUTED))
            dropdown:SetBackdropColor(0.035, 0.032, 0.028, 1)
            dropdown:SetBackdropBorderColor(0.27, 0.26, 0.23, 0.9)
        else
            local prefixReady = HasCompleteParentPath(index)
            local branchLearned = IsMenuBranchLearned(index)
            local available = GetAvailableMenuOptions(index)
            local parentIsTerminal = index > 2 and IsKnownTerminalAt(index - 1)
            local enabled = prefixReady and branchLearned and #available > 0 and not parentIsTerminal
            local waitingForRoot = index == 2 and (not LLRCA_DB.rootMenuOption or LLRCA_NormalizeMenuText(LLRCA_DB.rootMenuOption) == "")
            local waitingForRootBranch = index == 2 and not waitingForRoot and (not branchLearned or #available == 0)
            local waitingForChildBranch = index > 2 and prefixReady and not parentIsTerminal and (not branchLearned or #available == 0)
            local noFollowUps = prefixReady and parentIsTerminal

            dropdown:SetEnabled(enabled)
            dropdown:EnableMouse(enabled)
            dropdown:SetAlpha(enabled and 1 or ((waitingForRoot or waitingForRootBranch or waitingForChildBranch) and 0.88 or 0.65))
            if type(selected) == "string" and selected ~= "" then
                dropdown.valueText:SetText(selected)
            else
                dropdown.valueText:SetText(GetPathPlaceholder(index))
            end

            local textColor = WHITE
            if waitingForRoot or waitingForRootBranch or waitingForChildBranch then
                textColor = RED
            elseif not enabled then
                textColor = MUTED
            end
            dropdown.valueText:SetTextColor(unpack(textColor))
            dropdown:SetBackdropColor(enabled and 0.004 or 0.018, enabled and 0.004 or 0.016, enabled and 0.004 or 0.013, 1)
            if waitingForRoot or waitingForRootBranch or waitingForChildBranch then
                dropdown:SetBackdropBorderColor(0.82, 0.16, 0.12, 1)
            else
                dropdown:SetBackdropBorderColor(enabled and 0.40 or 0.27, enabled and 0.37 or 0.26, enabled and 0.31 or 0.23, 0.95)
            end
            if dropdown.arrow then dropdown.arrow:SetAlpha(enabled and 1 or 0.3) end
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", pathContent, "TOPLEFT", 0, -((index - 1) * PATH_ROW_HEIGHT))
        row:Show()
    end

    pathContent:SetSize(330, math.max(1, #LLRCA_DB.path * PATH_ROW_HEIGHT))
    local maxScroll = math.max(0, pathContent:GetHeight() - pathScroll:GetHeight())
    pathScroll:SetVerticalScroll(math.min(pathScroll:GetVerticalScroll() or 0, maxScroll))

    if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end
end

LLRCA_RefreshPathRows()

