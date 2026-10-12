-- Start/resume validation and Start/Stop wiring.
local Core = LLRCA_Core

--------------------------------------------------
-- START
--------------------------------------------------

-- Detect Landro's key-entry dialog. The edit box alone is not sufficient:
-- unrelated confirmation dialogs can also contain one.
function Core.IsCodeEntryPopupOpen()
    if not StaticPopup1 or not StaticPopup1.IsShown or not StaticPopup1:IsShown() then
        return false
    end
    local editBox = StaticPopup1EditBox or StaticPopup1.EditBox
    if not editBox then return false end
    if editBox.IsShown and not editBox:IsShown() then return false end

    local prompt = ""
    if StaticPopup1Text and StaticPopup1Text.GetText then
        prompt = StaticPopup1Text:GetText() or ""
    elseif StaticPopup1.text and StaticPopup1.text.GetText then
        prompt = StaticPopup1.text:GetText() or ""
    end
    prompt = string.lower(tostring(prompt))
    return string.find(prompt, "schlüssel", 1, true) ~= nil
        or string.find(prompt, "schlussel", 1, true) ~= nil
        or string.find(prompt, "key", 1, true) ~= nil
        or string.find(prompt, "code", 1, true) ~= nil
end

LLRCA_IsCodeEntryPopupOpen = Core.IsCodeEntryPopupOpen

local function FindOptionInList(options, value)
    local wanted = string.lower(LLRCA_NormalizeMenuText(value))
    if wanted == "" then return false end
    for _, option in ipairs(options or {}) do
        if string.lower(LLRCA_NormalizeMenuText(option)) == wanted then return true end
    end
    return false
end

function Core.IsKnownTerminalPath(path, depth)
    local key = LLRCA_MenuContextKey(path or {}, depth)
    if not key then return false end

    -- Endpoint and child-menu evidence must never disagree for the same route.
    -- If we have since observed real children beneath this exact context, an
    -- older endpoint marker is stale (for example, from an earlier popup race).
    local endpoints = LLRCA_DB.knownCodeEndpoints or {}
    if endpoints[key] ~= true then return false end
    local branch = (LLRCA_DB.knownMenuTree or {})[key]
    for _, value in ipairs(type(branch) == "table" and branch or {}) do
        local name = NormalizeMenuText(value)
        if name ~= "" and not LLRCA_IsIgnoredMenuOption(name) then
            endpoints[key] = nil
            return false
        end
    end
    return true
end


-- Find a configured route choice already visible in the currently open gossip.
-- This is deliberately exact-match only: never click an approximate option just
-- because its label resembles one of the configured steps.
local function FindVisibleConfiguredPathStep(options)
    local path = LLRCA_DB and LLRCA_DB.path or {}
    for index = #path, 2, -1 do
        local wanted = string.lower(LLRCA_NormalizeMenuText(path[index] or ""))
        if wanted ~= "" then
            for _, option in ipairs(options or {}) do
                local name = ""
                if type(option) == "table" then
                    name = LLRCA_NormalizeMenuText(option.name or option.text or option.label or option.gossipOptionName or "")
                elseif type(option) == "string" then
                    name = LLRCA_NormalizeMenuText(option)
                end
                if name ~= "" and not (LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(name))
                    and string.lower(name) == wanted then
                    return index, option
                end
            end
        end
    end
    return nil, nil
end

function Core.FindIgnoredNavigationOption(options)
    for _, option in ipairs(options or {}) do
        local name = ""
        if type(option) == "table" then
            name = LLRCA_NormalizeMenuText(option.name or option.text or option.label or option.gossipOptionName or "")
        elseif type(option) == "string" then
            name = LLRCA_NormalizeMenuText(option)
        end
        if name ~= "" and LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(name) then
            return option
        end
    end
    return nil
end

local function IsConfiguredPathStepVisible(options, pathIndex)
    local path = LLRCA_DB and LLRCA_DB.path or {}
    local wanted = string.lower(LLRCA_NormalizeMenuText(path[pathIndex] or ""))
    if wanted == "" then return false end
    for _, option in ipairs(options or {}) do
        local name = ""
        if type(option) == "table" then
            name = LLRCA_NormalizeMenuText(option.name or option.text or option.label or option.gossipOptionName or "")
        elseif type(option) == "string" then
            name = LLRCA_NormalizeMenuText(option)
        end
        if name ~= "" and not (LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(name))
            and string.lower(name) == wanted then
            return true
        end
    end
    return false
end

-- Return the configured-path depth whose learned menu branch exactly matches
-- the currently visible gossip options. This allows a restart from an already
-- open submenu without making the user click the same selections manually.
function Core.MatchOpenGossipContext(options)
    if type(options) ~= "table" or #options == 0 then return nil end

    -- Landro's short first page contains a navigation-only "other actions"
    -- option. Since that control is intentionally filtered out below, the
    -- remaining product names can accidentally be identical to a learned child
    -- menu. Never infer a route depth from this partial page: it must first be
    -- expanded through the navigation option.
    if Core.FindIgnoredNavigationOption and Core.FindIgnoredNavigationOption(options) then
        return nil
    end

    local visible, visibleSet = {}, {}
    for _, option in ipairs(options) do
        local name = ""
        if type(option) == "table" then
            name = LLRCA_NormalizeMenuText(option.name or option.text or option.label or option.gossipOptionName or "")
        elseif type(option) == "string" then
            name = LLRCA_NormalizeMenuText(option)
        end
        if name ~= "" and not (LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(name)) then
            local key = string.lower(name)
            if not visibleSet[key] then
                visibleSet[key] = true
                visible[#visible + 1] = key
            end
        end
    end
    if #visible == 0 then return nil end

    local path = LLRCA_DB.path or {}
    local tree = LLRCA_DB.knownMenuTree or {}
    -- Prefer the deepest matching context; deeper routes can occasionally
    -- expose a menu with the same labels as a parent menu.
    for depth = #path, 0, -1 do
        local key = LLRCA_MenuContextKey(path, depth)
        local branch = key and tree[key] or nil
        if type(branch) == "table" then
            local branchSet, branchCount = {}, 0
            for _, entry in ipairs(branch) do
                local name = LLRCA_NormalizeMenuText(entry)
                if name ~= "" and not (LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(name)) then
                    local normalized = string.lower(name)
                    if not branchSet[normalized] then
                        branchSet[normalized] = true
                        branchCount = branchCount + 1
                    end
                end
            end
            if branchCount == #visible then
                local matches = true
                for _, name in ipairs(visible) do
                    if not branchSet[name] then matches = false; break end
                end
                if matches then return depth end
            end
        end
    end
    return nil
end

function Core.SetActiveContextForDepth(depth)
    Core.activeMenuContext = {}
    local path = LLRCA_DB.path or {}
    for index = 1, tonumber(depth) or 0 do
        Core.activeMenuContext[index] = path[index]
    end
    Core.pendingSelection = nil
    Core.visibleOptionNamesByID = {}
    Core.visibleOptionNamesByIndex = {}
end

local function ValidateConfiguredPath()
    local rootOption = LLRCA_NormalizeMenuText(LLRCA_DB.rootMenuOption or "")
    local path = LLRCA_DB.path or {}
    if rootOption == "" or string.lower(LLRCA_NormalizeMenuText(path[1])) ~= string.lower(rootOption) then
        return LLRCA_L.ROOT_NOT_DETECTED
    end

    local selectedCount = 0
    local lastSelected = 1
    for index = 2, #path do
        local entry = LLRCA_NormalizeMenuText(path[index])
        local available = LLRCA_GetMenuOptionsForStep(index)
        if entry == "" then
            -- An already-confirmed code endpoint is a complete route even if a
            -- stale non-empty child list was left by an older addon version.
            local hasLaterSelection = false
            for later = index + 1, #path do
                if LLRCA_NormalizeMenuText(path[later]) ~= "" then
                    hasLaterSelection = true
                    return string.format(LLRCA_L.PATH_INCOMPLETE, index)
                end
            end
            if not hasLaterSelection and lastSelected >= 2 and Core.IsKnownTerminalPath(path, lastSelected) then
                return nil
            end
            -- Empty rows after a non-terminal route are allowed only when no
            -- child options are known at that level.
            if #available > 0 then
                return string.format(LLRCA_L.PATH_INCOMPLETE, index)
            end
            break
        end
        if #available == 0 then
            return LLRCA_L.LEARN_BRANCH
        end
        if not FindOptionInList(available, entry) then
            return string.format(LLRCA_L.PATH_OPTION_UNAVAILABLE, index)
        end
        selectedCount = selectedCount + 1
        lastSelected = index
    end

    if selectedCount == 0 then
        return string.format(LLRCA_L.PATH_INCOMPLETE, 2)
    end

    -- If Landro has already opened the key-entry dialog, this selection is a
    -- confirmed terminal action. The dialog is not a gossip submenu, so do not
    -- block Start merely because there is no learned child menu for it.
    if Core.IsCodeEntryPopupOpen() then return nil end

    -- Preserve a known endpoint between runs. The code popup closes after an
    -- attempt, but its learned route must remain startable without relearning.
    if Core.IsKnownTerminalPath(path, lastSelected) then
        return nil
    end

    -- A route is terminal only after the actual code-entry popup was observed.
    -- Empty cached branches can result from event timing and must never imply
    -- that the selected action is a code endpoint.
    local nextIndex = lastSelected + 1
    local nextLearned = LLRCA_IsMenuBranchLearnedForStep and LLRCA_IsMenuBranchLearnedForStep(nextIndex)
    local nextOptions = LLRCA_GetMenuOptionsForStep(nextIndex) or {}
    if not nextLearned or #nextOptions == 0 then
        return LLRCA_L.LEARN_CHILD_OPTIONS
    end
    if LLRCA_NormalizeMenuText(path[nextIndex] or "") == "" then
        return string.format(LLRCA_L.PATH_INCOMPLETE, nextIndex)
    end
    return nil
end

function LLRCA_CanStartAutomation()
    if Core.State.running then return true end
    if Core.IsCodeEntryPopupOpen() then return true end

    -- A visible Gossip dialog is not evidence that the saved route is complete.
    -- The Start button must remain disabled while the currently selected branch
    -- still requires a child step. A complete route can still be resumed from an
    -- already-open dialog because ValidateConfiguredPath accepts its saved leaf.
    return ValidateConfiguredPath() == nil
end

LLRCA_StartButton:SetScript("OnClick", function()
    if not Core.State.running then
        local codePopupAlreadyOpen = Core.IsCodeEntryPopupOpen()
        local openOptions = {}
        if not codePopupAlreadyOpen and C_GossipInfo and C_GossipInfo.GetOptions then
            openOptions = C_GossipInfo.GetOptions() or {}
        end

        -- A menu can be left open while stopped. Prefer resuming at the exact
        -- configured option visible in that menu, rather than blindly restarting
        -- at the root or rejecting the run based on a stale branch snapshot.
        local openContextDepth = (#openOptions > 0) and Core.MatchOpenGossipContext(openOptions) or nil
        local visibleStep, visibleOption = nil, nil
        if #openOptions > 0 then
            visibleStep, visibleOption = FindVisibleConfiguredPathStep(openOptions)
        end

        local ignoredNavigationOption = nil
        local path = LLRCA_DB and LLRCA_DB.path or {}
        local path2Visible = #openOptions > 0 and IsConfiguredPathStepVisible(openOptions, 2)
        -- If the navigation-only "other actions" entry is present before the
        -- configured step 2, select it first. Do not accidentally click a deeper
        -- item with the same label while the user is still on this intermediary menu.
        if not path2Visible and #openOptions > 0 then
            ignoredNavigationOption = Core.FindIgnoredNavigationOption(openOptions)
        end

        local message = ValidateConfiguredPath()
        local resumeDepth = nil
        local shouldResume = false

        if codePopupAlreadyOpen then
            message = nil
        elseif ignoredNavigationOption and not path2Visible and LLRCA_NormalizeMenuText(path[2] or "") ~= "" then
            -- The current menu is an intermediate dialog. Resolve the filtered
            -- navigation item first, even if a later selected label (e.g. a leaf
            -- item) also happens to be visible alongside it.
            message = nil
            resumeDepth = 1
            shouldResume = true
        elseif visibleStep then
            -- Exact visible route options are sufficient evidence to continue
            -- from the currently open menu, even if an older version's cached
            -- branch would otherwise make validation reject it.
            local prefixComplete = true
            for index = 2, visibleStep do
                if LLRCA_NormalizeMenuText(path[index] or "") == "" then
                    prefixComplete = false
                    break
                end
            end
            if prefixComplete then
                message = nil
                resumeDepth = visibleStep - 1
                shouldResume = true
            end
        elseif #openOptions > 0 and openContextDepth ~= nil then
            -- Even if the labels match a learned branch, do not start at the root
            -- when the menu is already open and no selected next step is visible.
            message = LLRCA_L.RESUME_GOSSIP_HINT
        elseif #openOptions > 0 then
            message = LLRCA_L.RESUME_GOSSIP_HINT
        end

        if message then
            if LLRCA_SetLearningStatus then
                LLRCA_SetLearningStatus(message, "error")
            elseif LLRCA_StatusText then
                LLRCA_StatusText:SetText(message)
                LLRCA_StatusText:SetTextColor(1, 0.35, 0.25)
            end
            print("[LLRCA] " .. message)
            return
        end

        Core.GenerateCodes()
        if codePopupAlreadyOpen then
            -- The popup watcher handles the already-open code dialog immediately.
            Core.State.pathIndex = #((LLRCA_DB and LLRCA_DB.path) or {}) + 1
        elseif shouldResume then
            Core.SetActiveContextForDepth(resumeDepth or 0)
            Core.State.pathIndex = (resumeDepth or 0) + 1
        else
            -- No dialog is open. Arm at the root and wait for the user's interaction.
            Core.SetActiveContextForDepth(0)
            Core.State.pathIndex = LLRCA_DB.rootIsNPC and 2 or 1
        end
        Core.State.running = true
        LLRCA_StartButton:SetText(LLRCA_L.STOP)
        Core.UpdateStatus(LLRCA_L.TALK)

        if ignoredNavigationOption then
            -- Prime the selected-option hook with the actual visible IDs/text,
            -- then advance through this navigation-only menu without adding it
            -- to the configured route.
            Core.visibleOptionNamesByID = {}
            Core.visibleOptionNamesByIndex = {}
            for index, option in ipairs(openOptions) do
                local id = option.gossipOptionID or option.id
                local name = LLRCA_NormalizeMenuText(option.name or option.text or option.label or option.gossipOptionName or "")
                Core.visibleOptionNamesByIndex[index] = name
                if id ~= nil then Core.visibleOptionNamesByID[id] = name end
            end
            local id = ignoredNavigationOption.gossipOptionID or ignoredNavigationOption.id
            if id ~= nil and C_GossipInfo and C_GossipInfo.SelectOption then
                Core.pendingSelection = {
                    parentContext = Core.CopyPath(Core.activeMenuContext),
                    name = LLRCA_NormalizeMenuText(ignoredNavigationOption.name or ignoredNavigationOption.text or ignoredNavigationOption.label or ignoredNavigationOption.gossipOptionName or ""),
                    ignoredNavigation = true,
                    serial = Core.pendingSelectionSerial + 1,
                }
                Core.pendingSelectionSerial = Core.pendingSelection.serial
                C_GossipInfo.SelectOption(id)
            else
                Core.State.running = false
                LLRCA_StartButton:SetText(LLRCA_L.START)
                Core.UpdateStatus(LLRCA_L.STOPPED)
                local hint = LLRCA_L.RESUME_GOSSIP_HINT
                if LLRCA_SetLearningStatus then LLRCA_SetLearningStatus(hint, "error") end
                print("[LLRCA] " .. hint)
            end
        elseif shouldResume and Core.HandleGossipOptions and #openOptions > 0 then
            -- Run the current visible menu immediately; no additional interaction
            -- is needed when the next selected step is already displayed.
            Core.HandleGossipOptions(openOptions)
        end
    else
        Core.State.running = false
        waitingForAccept = false
        wipe(Core.Codes)
        Core.State.current = 1
        Core.State.pathIndex = 1
        Core.activeMenuContext = {}
        Core.pendingSelection = nil
        Core.lastSelectedMenuContext = nil
        Core.wrongRootSelectionPending = false
        Core.visibleOptionNamesByID = {}
        Core.visibleOptionNamesByIndex = {}
        LLRCA_StartButton:SetText(LLRCA_L.START)
        Core.UpdateStatus(LLRCA_L.STOPPED)
        if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end
    end
end)

--------------------------------------------------
