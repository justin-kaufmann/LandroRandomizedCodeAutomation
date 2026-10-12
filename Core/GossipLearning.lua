-- Hierarchical gossip learning, route traversal, and context tracking.
local Core = LLRCA_Core

-- CONTEXT-AWARE GOSSIP LEARNING AND ORDERED PATH
--------------------------------------------------

local gossipFrame = CreateFrame("Frame")
gossipFrame:RegisterEvent("GOSSIP_SHOW")
gossipFrame:RegisterEvent("GOSSIP_CLOSED")

local function NormalizeMenuText(value)
    return LLRCA_NormalizeMenuText(value)
end

local function GetOptionName(option)
    if type(option) == "string" then return NormalizeMenuText(option) end
    if type(option) ~= "table" then return "" end
    return NormalizeMenuText(option.name or option.text or option.label or option.gossipOptionName or "")
end

-- Verify that the currently open Gossip really belongs to the selected route
-- parent. Landro's short product pages can contain the same visible item names
-- as a deeper submenu, and both may include the navigation-only "other actions"
-- option. Therefore labels alone are insufficient: the active route context and
-- the full filtered option set must both agree with the branch learned for this
-- exact parent.
local function ContextMatchesRoutePrefix(context, path, depth)
    depth = tonumber(depth) or 0
    if type(context) ~= "table" or type(path) ~= "table" or #context ~= depth then
        return false
    end
    for index = 1, depth do
        if string.lower(NormalizeMenuText(context[index])) ~= string.lower(NormalizeMenuText(path[index] or "")) then
            return false
        end
    end
    return true
end

local function CurrentOptionsMatchKnownBranch(options, path, parentDepth)
    if type(options) ~= "table" or #options == 0 then return false end

    -- Landro's short product page is a partial/intermediary dialog. The
    -- navigation-only "other actions" option is filtered from learned branches,
    -- so comparing the remaining product labels can falsely make this page look
    -- exactly like the saved root branch. Never use that partial page as proof
    -- that depth 1 is the current configured parent. ReconcileLearningContext
    -- will instead route through the navigation option and then re-check the
    -- expanded action list. Deeper contexts remain eligible for exact matching.
    if (tonumber(parentDepth) or 0) <= 1
        and Core.FindIgnoredNavigationOption
        and Core.FindIgnoredNavigationOption(options) then
        return false
    end

    local contextKey = LLRCA_MenuContextKey(path, parentDepth)
    local tree = type(LLRCA_DB) == "table" and LLRCA_DB.knownMenuTree or nil
    local expectedBranch = contextKey and type(tree) == "table" and tree[contextKey] or nil
    if type(expectedBranch) ~= "table" or #expectedBranch == 0 then return false end

    local visibleSet, visibleCount = {}, 0
    for _, option in ipairs(options) do
        local name = GetOptionName(option)
        if name ~= "" and not (LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(name)) then
            local key = string.lower(name)
            if not visibleSet[key] then
                visibleSet[key] = true
                visibleCount = visibleCount + 1
            end
        end
    end

    local expectedSet, expectedCount = {}, 0
    for _, entry in ipairs(expectedBranch) do
        local name = NormalizeMenuText(entry)
        if name ~= "" and not (LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(name)) then
            local key = string.lower(name)
            if not expectedSet[key] then
                expectedSet[key] = true
                expectedCount = expectedCount + 1
            end
        end
    end
    if visibleCount == 0 or visibleCount ~= expectedCount then return false end
    for key in pairs(visibleSet) do
        if not expectedSet[key] then return false end
    end
    return true
end

local function IsCurrentOptionsConfiguredParent(options, path, targetIndex)
    local parentDepth = (tonumber(targetIndex) or 1) - 1
    return parentDepth >= 1
        and ContextMatchesRoutePrefix(Core.activeMenuContext, path, parentDepth)
        and CurrentOptionsMatchKnownBranch(options, path, parentDepth)
end

-- Gossip events can arrive before GetOptions() has switched from the parent
-- dialog to the selected submenu. Compare option labels with the snapshot that
-- was visible when SelectOption was called, so stale parent options are never
-- learned under the child path.
local function OptionsMatchSelectionParent(options, snapshot)
    if type(snapshot) ~= "table" or #snapshot == 0 or #(options or {}) ~= #snapshot then
        return false
    end
    for index, option in ipairs(options or {}) do
        if string.lower(GetOptionName(option)) ~= string.lower(NormalizeMenuText(snapshot[index])) then
            return false
        end
    end
    return true
end

local function IsLandroStartOptionLabel(value)
    -- The generic "other actions" entry is not Landro's fixed start option.
    if LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(value) then return false end
    local lower = string.lower(NormalizeMenuText(value))
    if lower == "" then return false end

    -- The German client currently shows "Was für Aktionen bietet Ihr an?".
    -- Match the phrase wherever it appears in the option list, not only in
    -- element 1; some client/UI states include other option records first.
    local hasActionWord = string.find(lower, "aktion", 1, true) ~= nil
        or string.find(lower, "action", 1, true) ~= nil
        or string.find(lower, "option", 1, true) ~= nil
    local hasOfferWord = string.find(lower, "bietet", 1, true) ~= nil
        or string.find(lower, "offer", 1, true) ~= nil
        or string.find(lower, "what can i do for you", 1, true) ~= nil
        or string.find(lower, "what can i do", 1, true) ~= nil
    if hasActionWord and hasOfferWord then return true end
    if string.find(lower, "what can i do for you", 1, true) then return true end
    if string.find(lower, "was kann ich für euch tun", 1, true) then return true end
    return false
end

local function FindFixedRootOption(options)
    local savedRoot = string.lower(NormalizeMenuText(LLRCA_DB.rootMenuOption or ""))
    for _, option in ipairs(options or {}) do
        local name = GetOptionName(option)
        if name ~= "" and IsLandroStartOptionLabel(name) then
            return name, option
        end
    end

    -- If a language/client variant changes the wording after an earlier
    -- successful detection, accept the stored root when it appears first.
    local firstName = GetOptionName(options and options[1])
    if savedRoot ~= "" and string.lower(firstName) == savedRoot then
        return firstName, options and options[1]
    end
    return nil
end

Core.CopyPath = function(values)
    local result = {}
    for index, value in ipairs(values or {}) do result[index] = value end
    return result
end

-- Resolve the exact menu option that led to Landro's key-entry popup.
-- GOSSIP_CLOSED is not guaranteed to arrive before StaticPopup1 is observed;
-- in that race, Core.activeMenuContext still points at the PARENT dialog. Recording
-- an empty branch there would erase the selected option list in the dropdown.
-- Persist the exact configured route that opened Landro's key/code popup.
-- This function is used by both the GOSSIP_CLOSED handler and the popup watcher.
-- It was missing in an earlier package even though both call sites existed,
-- which meant endpoint learning could fail at runtime and Start became disabled
-- after Stop despite the selected route still being visible.
function Core.MarkCodeEndpointContext()
    if type(LLRCA_DB) ~= "table" then return false end
    if type(LLRCA_DB.knownCodeEndpoints) ~= "table" then
        LLRCA_DB.knownCodeEndpoints = {}
    end
    if type(LLRCA_DB.knownMenuTree) ~= "table" then
        LLRCA_DB.knownMenuTree = {}
    end

    local path = LLRCA_DB.path or {}
    local context = Core.CopyPath(Core.activeMenuContext or {})
    local targetDepth

    if Core.State.running then
        targetDepth = math.min((tonumber(Core.State.pathIndex) or 1) - 1, #path)
    elseif Core.learningTargetIndex then
        targetDepth = math.min(tonumber(Core.learningTargetIndex) or #context, #path)
    else
        targetDepth = #context
    end

    -- Prefer the selected route prefix if the live context matches it exactly.
    -- That keeps popup/GOSSIP_CLOSED event races from recording the parent menu
    -- as the endpoint and accidentally clearing the user's selected leaf.
    if targetDepth and targetDepth >= 2 and #context >= targetDepth then
        local matches = true
        for i = 1, targetDepth do
            if string.lower(NormalizeMenuText(context[i])) ~= string.lower(NormalizeMenuText(path[i] or "")) then
                matches = false
                break
            end
        end
        if matches then
            local route = {}
            for i = 1, targetDepth do route[i] = path[i] end
            context = route
        end
    end

    -- If context is still absent, recover it from a pending selected option.
    if #context == 0 and Core.pendingSelection then
        context = Core.CopyPath(Core.pendingSelection.parentContext)
        table.insert(context, Core.pendingSelection.name)
    end
    if #context < 2 then
        print("[LLRCA] " .. LLRCA_L.CODE_POPUP_CONTEXT_UNRESOLVED)
        return false
    end

    local contextKey = LLRCA_MenuContextKey(context, #context)
    if not contextKey then return false end

    LLRCA_DB.knownCodeEndpoints[contextKey] = true
    -- A code popup is a terminal child of this exact route. Replace stale
    -- guesses beneath that route with an explicitly learned empty branch.
    LLRCA_DB.knownMenuTree[contextKey] = {}
    Core.activeMenuContext = Core.CopyPath(context)
    Core.pendingSelection = nil
    Core.lastSelectedMenuContext = nil

    print("[LLRCA] " .. LLRCA_L.CODE_ENDPOINT_SAVED .. " (" .. table.concat(context, " > ") .. ")")
    return true
end

function Core.ResolveCodeEntryEndpointContext()
    -- During automation, the configured route prefix is authoritative. The
    -- Gossip close event may race with the secure post-hook in some clients.
    if Core.State.running and type(Core.lastSelectedMenuContext) == "table" and #Core.lastSelectedMenuContext > 0 then
        Core.activeMenuContext = Core.CopyPath(Core.lastSelectedMenuContext)
        Core.lastSelectedMenuContext = nil
        Core.pendingSelection = nil
        Core.pendingSelectionSerial = Core.pendingSelectionSerial + 1
        return
    end

    if Core.pendingSelection then
        Core.activeMenuContext = Core.CopyPath(Core.pendingSelection.parentContext)
        table.insert(Core.activeMenuContext, Core.pendingSelection.name)
        Core.lastSelectedMenuContext = Core.CopyPath(Core.activeMenuContext)
        Core.pendingSelectionSerial = Core.pendingSelectionSerial + 1
        Core.pendingSelection = nil
        return
    end

    -- If the hook missed the click, pathIndex has already advanced to the
    -- following step. Use the preceding configured path as a fallback.
    local path = LLRCA_DB and LLRCA_DB.path or {}
    local target
    if Core.State.running then
        target = math.min((tonumber(Core.State.pathIndex) or 1) - 1, #path)
    else
        target = tonumber(Core.learningTargetIndex)
    end
    if target and target >= 2 and #path >= target then
        local endpoint = {}
        for index = 1, target do endpoint[index] = path[index] end
        Core.activeMenuContext = endpoint
        Core.lastSelectedMenuContext = nil
    end
end

local function CaptureGossipSelection(optionID)
    local name = Core.visibleOptionNamesByID[optionID]
    local index = tonumber(optionID)
    if (not name or name == "") and index then
        name = Core.visibleOptionNamesByIndex[index]
    end
    name = NormalizeMenuText(name or "")
    if name == "" then return end

    Core.pendingSelectionSerial = Core.pendingSelectionSerial + 1
	local parentContext = Core.CopyPath(Core.activeMenuContext)
	local ignoredNavigation = LLRCA_IsIgnoredMenuOption and LLRCA_IsIgnoredMenuOption(name) or false

	-- The welcome action is a navigation transition in the current Landro
	-- NPC-root model, not a configurable route step.
	local parentIsLandroRoot = #parentContext == 1
		and string.lower(NormalizeMenuText(parentContext[1])) == "landro longshot"

	local savedRootText = NormalizeMenuText(LLRCA_DB.rootMenuOption or "")
	local savedRootLower = string.lower(savedRootText)

	local modernLandroRoot = LLRCA_DB.rootIsNPC == true
		or (Core.IsLandroNPC and Core.IsLandroNPC() == true)
		or savedRootLower == "landro longshot"
		-- Recover if an older run overwrote the saved root with this action label.
		or IsLandroStartOptionLabel(savedRootText)

	if parentIsLandroRoot
		and modernLandroRoot
		and IsLandroStartOptionLabel(name) then
		ignoredNavigation = true
	end

	local parentOptionNames = {}
    for index, optionName in ipairs(Core.visibleOptionNamesByIndex or {}) do
        parentOptionNames[index] = NormalizeMenuText(optionName)
    end

    Core.pendingSelection = {
        serial = Core.pendingSelectionSerial,
        parentContext = parentContext,
        parentOptionNames = parentOptionNames,
        name = name,
        ignoredNavigation = ignoredNavigation,
        learningRequestGeneration = tonumber(Core.learningRequestGeneration) or 0,
        staleOptionRetries = 0,
        staleOptionRetryScheduled = false,
    }

    -- When the run is waiting for path step 2, do not treat a manually clicked
    -- promotional/action option as the configured route. If it opens a code
    -- popup, the popup watcher will cancel it and recover via the navigation-only
    -- "other actions" entry instead of submitting a code to the wrong product.
    local path = LLRCA_DB and LLRCA_DB.path or {}
    local expected = NormalizeMenuText(path[2] or "")
    local rootName = NormalizeMenuText(path[1] or LLRCA_DB.rootMenuOption or "")
    local parentIsRoot = LLRCA_DB.rootIsNPC == true
        and #parentContext == 1
        and string.lower(NormalizeMenuText(parentContext[1])) == string.lower(rootName)
    local waitingForConfiguredStep2 = (Core.State.running and Core.State.pathIndex == 2)
        or (not Core.State.running and Core.learningTargetIndex == nil)
    if waitingForConfiguredStep2 and parentIsRoot and expected ~= ""
        and not ignoredNavigation and string.lower(name) ~= string.lower(expected) then
        Core.wrongRootSelectionPending = true
        print("[LLRCA] " .. LLRCA_L.OFF_ROUTE_ACTION_SELECTED)
    end

    if not Core.State.running then
        Core.lastSelectedMenuContext = Core.CopyPath(Core.activeMenuContext)
        table.insert(Core.lastSelectedMenuContext, name)
    end
end

-- Capture the option text when the player selects a visible gossip option.
-- Retail clients use C_GossipInfo.SelectOption; the legacy hook is included
-- for client builds that still expose SelectGossipOption.
if hooksecurefunc and C_GossipInfo and type(C_GossipInfo.SelectOption) == "function" then
    hooksecurefunc(C_GossipInfo, "SelectOption", function(optionID)
        CaptureGossipSelection(optionID)
    end)
end
if hooksecurefunc and type(SelectGossipOption) == "function" then
    hooksecurefunc("SelectGossipOption", function(index)
        CaptureGossipSelection(index)
    end)
end

local function UpdateLearningStatus()
    if Core.State.running then return end
    if not LLRCA_SetLearningStatus then return end

    local root = NormalizeMenuText(LLRCA_DB.rootMenuOption or "")
    if root == "" then
        LLRCA_SetLearningStatus(LLRCA_L.LEARN_ROOT_TALK, "error")
        return
    end

    local rootBranch = LLRCA_GetMenuOptionsForStep and LLRCA_GetMenuOptionsForStep(2) or {}
    local rootBranchLearned = LLRCA_IsMenuBranchLearnedForStep and LLRCA_IsMenuBranchLearnedForStep(2)
    if not rootBranchLearned or #rootBranch == 0 then
        LLRCA_SetLearningStatus(LLRCA_L.LEARN_ROOT_OPTIONS, "error")
        return
    end

    -- Find the last consecutive path choice. If a choice has not had its
    -- resulting submenu observed yet, point the user at that exact next step.
    local path = LLRCA_DB.path or {}
    local lastSelected = 1
    for index = 2, #path do
        if NormalizeMenuText(path[index]) == "" then break end
        lastSelected = index
    end

    -- A confirmed code-entry popup (or a saved terminal marker) means this
    -- configured route is complete. Do not show the misleading "open submenu"
    -- message for a route whose leaf is already known.
    if Core.IsCodeEntryPopupOpen() or (lastSelected >= 2 and Core.IsKnownTerminalPath(path, lastSelected)) then
        LLRCA_SetLearningStatus(LLRCA_L.PATH_READY, "ready")
        return
    end

    local nextIndex = lastSelected + 1
    if nextIndex <= #path and lastSelected >= 2 then
        local learned = LLRCA_IsMenuBranchLearnedForStep and LLRCA_IsMenuBranchLearnedForStep(nextIndex)
        local options = LLRCA_GetMenuOptionsForStep and LLRCA_GetMenuOptionsForStep(nextIndex) or {}
        if not learned then
            LLRCA_SetLearningStatus(LLRCA_L.LEARN_CHILD_OPTIONS, "error")
            return
        elseif #options == 0 then
            -- An empty learned branch is ambiguous until we actually observed
            -- the code popup. Keep this as a learning-needed state, not terminal.
            LLRCA_SetLearningStatus(LLRCA_L.LEARN_CHILD_OPTIONS, "error")
            return
        end
        if NormalizeMenuText(path[nextIndex] or "") == "" then
            LLRCA_SetLearningStatus(string.format(LLRCA_L.PATH_INCOMPLETE, nextIndex), "error")
            return
        end
    end

    LLRCA_SetLearningStatus(LLRCA_L.OPTIONS_READY, "ready")
end

LLRCA_RefreshLearningStatus = UpdateLearningStatus

local function DetectFixedRootOption(options)
    local name = FindFixedRootOption(options)
    if not name or name == "" then return false end

    local previousRoot = NormalizeMenuText(LLRCA_DB.rootMenuOption or "")
    local oldPath = LLRCA_DB.path or {}
    local wasPendingMigration = LLRCA_DB.pathMigrationPendingRootCheck
    if wasPendingMigration and string.lower(NormalizeMenuText(oldPath[2] or "")) == string.lower(name) then
        table.remove(oldPath, 2)
    end
    LLRCA_DB.pathMigrationPendingRootCheck = nil

    LLRCA_DB.rootMenuOption = name
    LLRCA_DB.path[1] = name
    if previousRoot ~= name and LLRCA_L.ROOT_DETECTED then
        print(string.format(LLRCA_L.ROOT_DETECTED, name))
    end
    if LLRCA_RefreshPathRows then LLRCA_RefreshPathRows() end
    if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end
    return true
end

local function AddUniqueOption(list, seen, name)
    name = NormalizeMenuText(name)
    local key = string.lower(name)
    if name == "" or seen[key] then return false end
    seen[key] = true
    table.insert(list, name)
    return true
end

function Core.ObserveGossipOptions(options, context)
    if type(LLRCA_DB.knownMenuTree) ~= "table" then LLRCA_DB.knownMenuTree = {} end
    if type(LLRCA_DB.knownMenuOptions) ~= "table" then LLRCA_DB.knownMenuOptions = {} end

    local contextKey = LLRCA_MenuContextKey(context or {}, #(context or {}))
    local addedHere = 0
    local branchChanged = false
    if contextKey ~= nil then
        local previousBranch = LLRCA_DB.knownMenuTree[contextKey]
        local previousSeen = {}
        if type(previousBranch) == "table" then
            for _, value in ipairs(previousBranch) do
                if type(value) == "string" then previousSeen[string.lower(NormalizeMenuText(value))] = true end
            end
        else
            previousBranch = {}
        end

        -- A key-entry popup is not a gossip submenu. If a close-event race
        -- points at the wrong context, do not erase a known non-empty branch.
        -- A genuine code endpoint is explicitly marked before this is called.
        if #(options or {}) == 0 and #previousBranch > 0
            and not (LLRCA_DB.knownCodeEndpoints and LLRCA_DB.knownCodeEndpoints[contextKey]) then
            return
        end

        -- Store the exact options visible in this dialog. This prevents options
        -- learned under the same parent at another time from lingering if they
        -- are no longer available in the currently observed menu.
        local branch, branchSeen = {}, {}
        for _, option in ipairs(options or {}) do
            local name = GetOptionName(option)
            local key = string.lower(name)
            if name ~= "" and not LLRCA_IsIgnoredMenuOption(name) and not branchSeen[key] then
                branchSeen[key] = true
                table.insert(branch, name)
                if not previousSeen[key] then addedHere = addedHere + 1 end
            end
        end

        local routePath = LLRCA_DB.path or {}
        local contextDepth = #(context or {})
        local configuredNext = NormalizeMenuText(routePath[contextDepth + 1] or "")
        local configuredNextKey = string.lower(configuredNext)
        local previousHadNext = configuredNext ~= "" and previousSeen[configuredNextKey] == true
        local currentHasNext = configuredNext ~= "" and branchSeen[configuredNextKey] == true
        local explicitlyLearningThisBranch = Core.learningTargetIndex ~= nil and contextDepth >= (tonumber(Core.learningTargetIndex) or 99)
        local protectConfiguredRoute = #previousBranch > 0 and previousHadNext and not currentHasNext and not explicitlyLearningThisBranch

        if protectConfiguredRoute then
            -- The current dialog is likely an intermediate/stale menu, not the
            -- route's parent branch. Do not overwrite the learned branch and do
            -- not let UI refresh clear an already selected path step.
            branchChanged = false
        else
            if #branch ~= #previousBranch then
                branchChanged = true
            else
                for index, value in ipairs(branch) do
                    if string.lower(NormalizeMenuText(value)) ~= string.lower(NormalizeMenuText(previousBranch[index])) then
                        branchChanged = true
                        break
                    end
                end
            end
			
			local endpoints = LLRCA_DB.knownCodeEndpoints

			if #branch > 0
				and type(endpoints) == "table"
				and endpoints[contextKey] == true then
				-- Keine neuen Menüoptionen unter einem bestätigten Endpunkt speichern,
				-- wenn der Dialog noch dem vorherigen Kontext zugeordnet ist.
				return
			end
			
            LLRCA_DB.knownMenuTree[contextKey] = branch

            -- A context that now exposes real child choices cannot still be a
            -- terminal code-popup route. Drop any stale marker for this exact
            -- route; the endpoint will be re-added only if its code popup opens.
            if #branch > 0 and type(LLRCA_DB.knownCodeEndpoints) == "table" then
                LLRCA_DB.knownCodeEndpoints[contextKey] = nil
            end
        end
    end

    -- Keep the old flat index for backwards compatibility/diagnostics only;
    -- the dropdowns never use this list to populate a menu branch.
    local flatSeen = {}
    for _, value in ipairs(LLRCA_DB.knownMenuOptions) do
        if type(value) == "string" then flatSeen[string.lower(NormalizeMenuText(value))] = true end
    end
    for _, option in ipairs(options or {}) do
        local name = GetOptionName(option)
        if not LLRCA_IsIgnoredMenuOption(name) then AddUniqueOption(LLRCA_DB.knownMenuOptions, flatSeen, name) end
    end

    if branchChanged then
        if LLRCA_RefreshPathRows then LLRCA_RefreshPathRows() end
    end
    if addedHere > 0 and LLRCA_L.OPTIONS_LEARNED then
        print(string.format(LLRCA_L.OPTIONS_LEARNED, addedHere))
    end
    if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end
end

local function FindPathOption(options, desired)
    local wanted = string.lower(NormalizeMenuText(desired))
    if wanted == "" then return nil end
    local exactMatch
    local partialMatch
    local partialCount = 0
    for _, option in ipairs(options or {}) do
        local optionLabel = GetOptionName(option)
        if not LLRCA_IsIgnoredMenuOption(optionLabel) then
            local name = string.lower(optionLabel)
            if name == wanted then
                exactMatch = option
                break
            elseif string.find(name, wanted, 1, true) then
                partialMatch = option
                partialCount = partialCount + 1
            end
        end
    end
    if exactMatch then return exactMatch end
    if partialCount == 1 then return partialMatch end
    return nil
end

local function AdvanceLearningNavigation(options, context)
    if not Core.learningTargetIndex or Core.State.running then return false end
    local path = LLRCA_DB.path or {}
    local target = tonumber(Core.learningTargetIndex)
    if not target or target < 2 then Core.CompleteLearningRequest(); return false end

    -- The live dialog must correspond to a prefix of the configured route.
    -- This prevents the learner from clicking options on an unrelated NPC.
    context = context or Core.activeMenuContext or {}
    for i = 1, #context do
        if NormalizeMenuText(context[i]) ~= NormalizeMenuText(path[i] or "") then
            return false
        end
    end

    local nextIndex = #context + 1
    if nextIndex > target then
        -- We have reached the selected path endpoint; this dialog's options
        -- have already been recorded by Core.ObserveGossipOptions.
        Core.CompleteLearningRequest()
        if LLRCA_RefreshPathRows then LLRCA_RefreshPathRows() end
        if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end
        print("[LLRCA] " .. string.format(LLRCA_L.LEARNING_PATH_CAPTURED, target))
        return true
    end

    local desired = NormalizeMenuText(path[nextIndex] or "")
    if desired == "" then
        Core.CompleteLearningRequest()
        if LLRCA_SetLearningStatus then
            LLRCA_SetLearningStatus(LLRCA_L.PREVIOUS_PATH_STEPS_REQUIRED, "error")
        end
        return true
    end

    local option = FindPathOption(options, desired)
    if not option then
        -- Match the normal automation's navigation behavior: if the selected
        -- step is not in this page because Landro is showing only the first
        -- few actions, use the explicit "other actions" navigation entry and
        -- retry against the expanded list. This option is navigation only and
        -- is never added to the configured route.
        local navigationOption = Core.FindIgnoredNavigationOption(options)
        if navigationOption then
            local navigationID = navigationOption.gossipOptionID or navigationOption.id
            if navigationID ~= nil and C_GossipInfo and C_GossipInfo.SelectOption then
                print("[LLRCA] " .. LLRCA_L.AUTO_OPEN_OTHER_ACTIONS)
                C_GossipInfo.SelectOption(navigationID)
                return true
            end
        end
        -- Wait for a matching dialog to be opened; never guess a similar option.
        if LLRCA_SetLearningStatus then
            LLRCA_SetLearningStatus(LLRCA_L.OPEN_LANDRO_START_FOR_LEARNING, "error")
        end
        return true
    end

    local optionID = option.gossipOptionID or option.id
    if optionID == nil or not C_GossipInfo or not C_GossipInfo.SelectOption then
        if LLRCA_SetLearningStatus then
            LLRCA_SetLearningStatus(LLRCA_L.MENU_OPTION_CANNOT_BE_OPENED, "error")
        end
        return true
    end

    print("[LLRCA] " .. LLRCA_L.LEARNING_SUBMENU .. ": " .. tostring(desired))
    C_GossipInfo.SelectOption(optionID)
    return true
end

-- A path selection can change while a previous leaf's code popup is still open.
-- Keep a serialised request so the newest selected route wins, even if multiple
-- changes happen while the popup is being dismissed.
local learningRequestSerial = 0
local pendingLearningTargetIndex = nil
local ReconcileLearningContext

local function RebaseActiveContextToCurrentPath(path)
    local context = Core.activeMenuContext or {}
    local common = 0
    local limit = math.min(#context, #path)
    for index = 1, limit do
        local currentName = string.lower(NormalizeMenuText(context[index]))
        local routeName = string.lower(NormalizeMenuText(path[index] or ""))
        if currentName == "" or routeName == "" or currentName ~= routeName then break end
        common = index
    end
    local rebased = {}
    for index = 1, common do rebased[index] = path[index] end
    Core.activeMenuContext = rebased
    Core.lastSelectedMenuContext = nil
end

function Core.CancelPendingLearningRequest()
    learningRequestSerial = learningRequestSerial + 1
    Core.learningRequestGeneration = learningRequestSerial
    pendingLearningTargetIndex = nil
    Core.learningTargetIndex = nil
    Core.learningReanchorPending = false
    Core.pendingSelection = nil
    Core.lastSelectedMenuContext = nil
    Core.wrongRootSelectionPending = false
    -- Do not clear learningPopupCancelPending here. A queued popup-close callback
    -- still owns that flag and must finish before the old popup can be observed
    -- as a valid endpoint again.
end

function Core.CompleteLearningRequest()
    pendingLearningTargetIndex = nil
    Core.learningTargetIndex = nil
    Core.learningReanchorPending = false
end

local function ProcessLearningPathRequest(targetIndex, serial)
    if serial ~= learningRequestSerial then return end
    if Core.State.running then
        if LLRCA_SetLearningStatus then
            LLRCA_SetLearningStatus(LLRCA_L.STOP_BEFORE_LEARNING, "error")
        end
        return
    end
    -- If another dropdown was changed during an existing popup-close delay, let
    -- that callback resume the newest request instead of racing it immediately.
    if Core.learningPopupCancelPending then return end

    targetIndex = tonumber(pendingLearningTargetIndex or targetIndex)
    if not targetIndex or targetIndex < 2 then return end

    -- If the previous route opened a terminal popup, cancel it and retry using
    -- the latest target selection. Do not capture targetIndex in the delayed
    -- callback: the user may choose another route before the popup closes.
    if Core.IsCodeEntryPopupOpen and Core.IsCodeEntryPopupOpen() then
        if Core.learningPopupCancelPending then return end

        local cancelButton = StaticPopup1Button2
        if not (cancelButton and cancelButton.IsVisible and cancelButton:IsVisible()
            and cancelButton.IsEnabled and cancelButton:IsEnabled()) then
            if LLRCA_SetLearningStatus then
                LLRCA_SetLearningStatus(LLRCA_L.CLOSE_PREVIOUS_CODE_POPUP_FIRST, "error")
            end
            return
        end

        Core.learningPopupCancelPending = true
        if LLRCA_SetLearningStatus then
            LLRCA_SetLearningStatus(LLRCA_L.CLOSING_PREVIOUS_POPUP_AND_NAVIGATING, "learning")
        end
        cancelButton:Click()

        local function ResumeLatestRequest()
            Core.learningPopupCancelPending = nil
            local latestTarget = pendingLearningTargetIndex
            if not latestTarget or Core.State.running then return end
            ProcessLearningPathRequest(latestTarget, learningRequestSerial)
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0.22, ResumeLatestRequest)
        else
            ResumeLatestRequest()
        end
        return
    end

    local path = LLRCA_DB.path or {}
    for index = 2, targetIndex do
        if NormalizeMenuText(path[index] or "") == "" then
            Core.CompleteLearningRequest()
            if LLRCA_SetLearningStatus then
                LLRCA_SetLearningStatus(LLRCA_L.PREVIOUS_PATH_STEPS_REQUIRED, "error")
            end
            return
        end
    end

    Core.learningTargetIndex = targetIndex
    local options = (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.GetOptions()) or {}

    if #options == 0 then
        -- A cancelled code popup may have closed the active Gossip session as
        -- well. Drop only transient context, not the route request; the next
        -- GOSSIP_SHOW will resume the same selected route from Landro's root.
        Core.pendingSelection = nil
        Core.lastSelectedMenuContext = nil
        Core.wrongRootSelectionPending = false
        Core.activeMenuContext = {}
        Core.visibleOptionNamesByID = {}
        Core.visibleOptionNamesByIndex = {}
        Core.learningReanchorPending = true
        if LLRCA_SetLearningStatus then
            LLRCA_SetLearningStatus(LLRCA_L.GOSSIP_NOT_ACTIVE_REOPEN_LANDRO, "learning")
        end
        return
    end

    -- A selection that was already sent to WoW may still be transitioning to its
    -- child dialog. Let the regular event handler resolve that transition first;
    -- it will then re-run this request if the resulting context belongs to the
    -- previous route rather than the user's current selection.
    if Core.pendingSelection then
        Core.ProcessCurrentGossipOptions()
        return
    end

    Core.lastSelectedMenuContext = nil
    Core.wrongRootSelectionPending = false
    -- A request is reconciled against the live Gossip options before any click.
    Core.learningReanchorPending = true

    if Core.ProcessCurrentGossipOptions then
        Core.ProcessCurrentGossipOptions()
        return
    end

    if LLRCA_SetLearningStatus then
        LLRCA_SetLearningStatus(LLRCA_L.REOPEN_LANDRO_RESUME_SELECTED_ROUTE, "learning")
    end
end

function LLRCA_RequestLearnPath(targetIndex)
    if Core.State.running then
        if LLRCA_SetLearningStatus then
            LLRCA_SetLearningStatus(LLRCA_L.STOP_BEFORE_LEARNING, "error")
        end
        return
    end

    targetIndex = tonumber(targetIndex)
    if not targetIndex or targetIndex < 2 then return end

    -- Every dropdown change creates a new request generation. If the user
    -- changes step 2 twice while a popup is closing, the delayed callback must
    -- follow the latest path, never an earlier selection.
    learningRequestSerial = learningRequestSerial + 1
    Core.learningRequestGeneration = learningRequestSerial
    pendingLearningTargetIndex = targetIndex
    Core.learningTargetIndex = targetIndex
    Core.wrongRootSelectionPending = false
    Core.learningReanchorPending = true

    -- Keep only the part of the previous menu context that is still a prefix of
    -- the newly selected route. An in-flight click is separately marked stale by
    -- its generation and cannot become the context for the new route.
    RebaseActiveContextToCurrentPath(LLRCA_DB.path or {})

    if Core.IsCodeEntryPopupOpen and Core.IsCodeEntryPopupOpen() then
        Core.pendingSelection = nil
        Core.pendingSelectionSerial = (tonumber(Core.pendingSelectionSerial) or 0) + 1
        Core.lastSelectedMenuContext = nil
    elseif Core.pendingSelection then
        Core.pendingSelection.superseded = true
    else
        Core.lastSelectedMenuContext = nil
    end

    ProcessLearningPathRequest(targetIndex, learningRequestSerial)
end

Core.HandleGossipOptions = function(options)
    options = options or {}

    -- Once Landro's key-entry popup is open, the old Gossip options may still
    -- be returned briefly by the client while GOSSIP_CLOSED/GOSSIP_SHOW events
    -- settle. They are not a new submenu. Processing them as such could hit the
    -- empty next path step and stop the entire multi-iteration run after code 1.
    -- The popup watcher handles endpoint persistence and advances the iteration
    -- when the code popup actually closes after confirmation.
    if Core.State.running and Core.IsCodeEntryPopupOpen() then
        return
    end

    local context = Core.activeMenuContext or {}
    if #context == 0 then DetectFixedRootOption(options) end
    Core.ObserveGossipOptions(options, context)

    if not Core.State.running and Core.learningTargetIndex then
        if AdvanceLearningNavigation(options, context) then return end
    end
    if not Core.State.running then return end
    local path = LLRCA_DB.path or {}
    local desired = path[Core.State.pathIndex]
    if type(desired) ~= "string" or NormalizeMenuText(desired) == "" then
        if Core.State.running then
            local hasUsableOption = false
            for _, visibleOption in ipairs(options) do
                local visibleName = GetOptionName(visibleOption)
                if visibleName ~= "" and not LLRCA_IsIgnoredMenuOption(visibleName) then
                    hasUsableOption = true
                    break
                end
            end
            if hasUsableOption then
                -- The selected final choice revealed another submenu, so the
                -- previously assumed endpoint was not terminal. Keep the newly
                -- learned branch, stop before selecting anything unexpectedly,
                -- and prompt the user to configure the newly available row.
                local missingStep = tonumber(Core.State.pathIndex) or (#path + 1)
                Core.State.running = false
                wipe(Core.Codes)
                Core.State.current = 1
                Core.State.pathIndex = 1
                Core.pendingSelection = nil
                Core.lastSelectedMenuContext = nil
                LLRCA_StartButton:SetText(LLRCA_L.START)
                Core.UpdateStatus(LLRCA_L.STOPPED)
                if LLRCA_RefreshPathRows then LLRCA_RefreshPathRows() end
                local message = string.format(LLRCA_L.PATH_INCOMPLETE, missingStep)
                if LLRCA_SetLearningStatus then LLRCA_SetLearningStatus(message, "error") end
                print("[LLRCA] " .. message)
            end
        end
        return
    end
    local option = FindPathOption(options, desired)
    if not option then
        -- Landro's initial product dialog can be open while the automation is
        -- waiting for the configured step 2. The target (e.g. "Helden von Azeroth")
        -- is only offered after selecting the filtered "other actions" entry.
        -- Perform that navigation automatically whenever the target is absent.
        if Core.State.pathIndex == 2 and NormalizeMenuText(path[2] or "") ~= "" then
            local navigationOption = Core.FindIgnoredNavigationOption(options)
            local navigationID = navigationOption and (navigationOption.gossipOptionID or navigationOption.id)
            if navigationOption and navigationID ~= nil and C_GossipInfo and C_GossipInfo.SelectOption then
                print("[LLRCA] " .. string.format(LLRCA_L.OPENING_OTHER_ACTIONS_FOR_SELECTED_OPTION, GetOptionName(navigationOption)))
                if LLRCA_SetLearningStatus then
                    LLRCA_SetLearningStatus(LLRCA_L.OPEN_ALL_ACTIONS_AND_RESUME, "learning")
                end
                C_GossipInfo.SelectOption(navigationID)
                return
            end
            if LLRCA_SetLearningStatus then
                LLRCA_SetLearningStatus(LLRCA_L.SAVED_MENU_OPTION_NOT_VISIBLE, "error")
            end
        end
        return
    end

    local selectedIndex = Core.State.pathIndex
    local selectedName = NormalizeMenuText(GetOptionName(option))
    local selectedContext = {}
    for index = 1, selectedIndex - 1 do selectedContext[index] = path[index] end
    table.insert(selectedContext, selectedName)
    Core.lastSelectedMenuContext = Core.CopyPath(selectedContext)

    print("[LLRCA] " .. string.format(LLRCA_L.SELECTING_MENU_STEP, tostring(Core.State.pathIndex)) .. " " .. tostring(selectedName))
    Core.State.pathIndex = Core.State.pathIndex + 1
    C_GossipInfo.SelectOption(option.gossipOptionID or option.id)
end

local gossipReadSerial = 0

local function IsLandroNPC()
    local name = UnitName and UnitName("npc")
    if type(name) == "string" and name ~= "" then
        return string.find(string.lower(name), "landro", 1, true) ~= nil
    end
    -- Some client builds do not expose the gossip unit token. Treat identity
    -- as unknown (nil), not false, so the saved Landro root can be used safely.
    local text = (GetGossipText and GetGossipText()) or ""
    if type(text) == "string" and string.find(string.lower(text), "landro", 1, true) then
        return true
    end
    return nil
end

-- Expose the local NPC identity check to the explicit path-learning request.
-- This lets a dropdown click safely re-anchor a stale context when Landro is
-- open, without applying this shortcut to unrelated NPC gossip.
Core.IsLandroNPC = IsLandroNPC

local function EnsureLandroNPCRoot()
    local root = "Landro Longshot"
    local previous = NormalizeMenuText(LLRCA_DB.rootMenuOption or "")
    LLRCA_DB.rootIsNPC = true
    LLRCA_DB.rootMenuOption = root
    if type(LLRCA_DB.path) ~= "table" then LLRCA_DB.path = { root, "", "" } end
    LLRCA_DB.path[1] = root
    Core.activeMenuContext = { root }
    if previous ~= root and LLRCA_L.ROOT_DETECTED then
        print(string.format(LLRCA_L.ROOT_DETECTED, root))
    end
    if LLRCA_RefreshPathRows then LLRCA_RefreshPathRows() end
end

-- Reconcile the currently visible Gossip menu after a path edit. This is
-- intentionally based on the whole configured route, not special cases for
-- steps 2/3: the same logic works for every selected depth.
ReconcileLearningContext = function(options, targetIndex)
    options = options or {}
    targetIndex = tonumber(targetIndex or Core.learningTargetIndex)
    if #options == 0 or not targetIndex or targetIndex < 2 then return false end

    local path = LLRCA_DB and LLRCA_DB.path or {}
    local root = NormalizeMenuText(path[1] or LLRCA_DB.rootMenuOption or "")
    local rootIsLandro = string.find(string.lower(root), "landro", 1, true) ~= nil
        or (Core.IsLandroNPC and Core.IsLandroNPC() == true)
    local navigationOption = Core.FindIgnoredNavigationOption and Core.FindIgnoredNavigationOption(options) or nil
    local step2 = NormalizeMenuText(path[2] or "")
    local step2Visible = step2 ~= "" and FindPathOption(options, step2) ~= nil
    local targetLabel = NormalizeMenuText(path[targetIndex] or "")
    local targetVisible = targetLabel ~= "" and FindPathOption(options, targetLabel) ~= nil
    local context = Core.activeMenuContext or {}
    local contextDepth = #context
    local contextIsPrefix = ContextMatchesRoutePrefix(context, path, contextDepth)
    local optionsMatchContext = contextIsPrefix and CurrentOptionsMatchKnownBranch(options, path, contextDepth)
    local currentParentMatches = IsCurrentOptionsConfiguredParent(options, path, targetIndex)

    -- Prefer a confirmed parent menu when the next requested item is visible.
    -- This prevents the root fallback from hijacking a legitimate deeper menu
    -- merely because that menu also happens to offer the navigation control.
    if currentParentMatches and targetVisible then
        Core.SetActiveContextForDepth(targetIndex - 1)
        Core.learningReanchorPending = false
        return true
    end

    -- Try identifying the live dialog from its complete learned option set.
    -- Partial Landro product pages are explicitly rejected by this matcher.
    local matchedDepth = Core.MatchOpenGossipContext and Core.MatchOpenGossipContext(options) or nil
    if matchedDepth ~= nil then
        Core.SetActiveContextForDepth(matchedDepth)
        Core.learningReanchorPending = false
        return true
    end

    -- If this is Landro's short product page (or an unverified old-route page),
    -- use the navigation-only option when the current context cannot prove that
    -- the visible options belong to the new selected parent chain.
    if rootIsLandro and navigationOption
        and ((targetIndex == 2 and not step2Visible)
            or (not optionsMatchContext and not (currentParentMatches and targetVisible))) then
        Core.activeMenuContext = { root ~= "" and root or "Landro Longshot" }
        Core.pendingSelection = nil
        Core.lastSelectedMenuContext = nil
        Core.learningReanchorPending = false
        return true
    end

    -- During clean learning the first configurable choice can be selected from
    -- a live Landro action list even before its root branch has been persisted.
    if rootIsLandro and targetIndex == 2 and step2Visible then
        Core.activeMenuContext = { root ~= "" and root or "Landro Longshot" }
        Core.learningReanchorPending = false
        return true
    end

    -- A selected deeper route may continue only when the exact currently visible
    -- menu agrees with the known parent branch. Never guess from label overlap.
    if currentParentMatches or optionsMatchContext then
        Core.SetActiveContextForDepth(contextDepth)
        Core.learningReanchorPending = false
        return true
    end

    return false
end

Core.ProcessCurrentGossipOptions = function()
	local options = (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.GetOptions()) or {}
	local resolvedPendingTransition = false
	local resumeConfiguredRouteAfterNavigation = false
    -- Gossip events can race the client-side menu update. A click from the
    -- current route generation must wait for its child menu; a click from an
    -- older generation must never become the context for the newly selected path.
    local pending = Core.pendingSelection
    local hasLearningRequest = not Core.State.running and Core.learningTargetIndex ~= nil
    local staleGeneration = pending and hasLearningRequest
        and (tonumber(pending.learningRequestGeneration) or 0) ~= (tonumber(Core.learningRequestGeneration) or 0)

    if hasLearningRequest and pending and not Core.IsCodeEntryPopupOpen()
        and OptionsMatchSelectionParent(options, pending.parentOptionNames) then
        pending.staleOptionRetries = (tonumber(pending.staleOptionRetries) or 0) + 1
        if pending.staleOptionRetries <= 8 and C_Timer and C_Timer.After then
            if not pending.staleOptionRetryScheduled then
                pending.staleOptionRetryScheduled = true
                local pendingSerial = pending.serial
                C_Timer.After(0.12, function()
                    local current = Core.pendingSelection
                    if not current or current.serial ~= pendingSerial then return end
                    current.staleOptionRetryScheduled = false
                    Core.ProcessCurrentGossipOptions()
                end)
            end
            -- Don't click anything on the parent page while WoW may still be
            -- transitioning from the old click. Retry briefly, then recover.
            return
        elseif staleGeneration then
            -- The superseded transition never changed the menu. Release it and
            -- retry navigation from the options actually visible now.
            Core.pendingSelection = nil
            Core.pendingSelectionSerial = (tonumber(Core.pendingSelectionSerial) or 0) + 1
            Core.lastSelectedMenuContext = nil
            Core.learningReanchorPending = true
            pending = nil
        else
            if not pending.staleStatusShown then
                pending.staleStatusShown = true
                if LLRCA_SetLearningStatus then
                    LLRCA_SetLearningStatus(LLRCA_L.WAITING_FOR_UPDATED_SUBMENU, "error")
                end
            end
            return
        end
    elseif staleGeneration then
        -- The obsolete click has produced a different dialog. Discard its old
        -- context assignment and infer the live menu against the latest route.
        Core.pendingSelection = nil
        Core.pendingSelectionSerial = (tonumber(Core.pendingSelectionSerial) or 0) + 1
        Core.lastSelectedMenuContext = nil
        Core.learningReanchorPending = true
        pending = nil
    end

    if hasLearningRequest and Core.learningReanchorPending then
        if not ReconcileLearningContext or not ReconcileLearningContext(options, Core.learningTargetIndex) then
            if LLRCA_SetLearningStatus then
                LLRCA_SetLearningStatus(LLRCA_L.GOSSIP_ROUTE_CONTEXT_MISMATCH, "error")
            end
            return
        end
    end

    -- If the manual off-route choice led to another gossip dialog rather than a
    -- code popup, it is not the wrong-popup case anymore. Let normal navigation
    -- logic handle the visible menu without cancelling any later valid endpoint.
    if Core.wrongRootSelectionPending and not Core.IsCodeEntryPopupOpen() then
        Core.wrongRootSelectionPending = false
    end

    -- Learning fallback: Landro's root action dialog can remain open after a
    -- previous route/iteration, while activeMenuContext still points at an old
    -- submenu. If the user has explicitly requested learning of a configured
    -- route and step 2 is not on this page, the visible navigation-only
    -- "other actions" entry is strong evidence that this is Landro's first
    -- action page. Re-anchor to the known NPC root before handling the options;
    -- AdvanceLearningNavigation can then select the navigation entry and resume
    -- the chosen path automatically. Without this, the stale context rejected
    -- the dialog as unrelated and the learner only displayed "open submenu".
    local learningPath = LLRCA_DB and LLRCA_DB.path or {}
    local learningTarget = tonumber(Core.learningTargetIndex)
    local configuredRoot = NormalizeMenuText(learningPath[1] or LLRCA_DB.rootMenuOption or "")
    local configuredRootIdentifiesLandro = string.find(string.lower(configuredRoot), "landro", 1, true) ~= nil
    if not Core.State.running
        and learningTarget and learningTarget >= 2
        and not Core.pendingSelection
        -- Older SavedVariables may lack rootIsNPC even though the saved root is
        -- Landro. Recognize either the live NPC or the saved Landro root; when
        -- the navigation-only entry is visible and step 2 is not, re-anchor to
        -- that root so the learner selects "other actions" automatically.
        and (LLRCA_DB.rootIsNPC == true or IsLandroNPC() == true or configuredRootIdentifiesLandro)
        and configuredRoot ~= ""
    then
        local navigationOption = Core.FindIgnoredNavigationOption(options)
        local configuredStep2 = NormalizeMenuText(learningPath[2] or "")
        local step2Visible = configuredStep2 ~= "" and FindPathOption(options, configuredStep2) ~= nil
        local currentParentMatches = learningTarget
            and IsCurrentOptionsConfiguredParent(options, learningPath, learningTarget)
        if navigationOption and not step2Visible
            and (learningTarget == 2 or not currentParentMatches) then
            -- Only the short/root action page should re-anchor to Landro's root.
            -- A deeper selected submenu can also contain "other actions" while
            -- step 2 is naturally not visible; if its context and option set match
            -- the configured parent branch, preserve it so the chosen leaf is
            -- clicked and its code popup can confirm the endpoint.
            Core.activeMenuContext = { (NormalizeMenuText(learningPath[1] or LLRCA_DB.rootMenuOption or "Landro Longshot")) }
            Core.pendingSelection = nil
            Core.lastSelectedMenuContext = nil
        end
    end

    -- Keep a current ID -> label map before processing context or triggering any
    -- selection. This makes both manual clicks and the optional fixed-root click
    -- attributable to the correct parent branch.
    Core.visibleOptionNamesByID = {}
    Core.visibleOptionNamesByIndex = {}
    for index, option in ipairs(options) do
        local optionID = option.gossipOptionID or option.id
        local optionName = GetOptionName(option)
        if optionName ~= "" then
            Core.visibleOptionNamesByIndex[index] = optionName
            if optionID ~= nil then Core.visibleOptionNamesByID[optionID] = optionName end
        end
    end

	local rootName, rootOption = FindFixedRootOption(options)
	local npcIsLandro = IsLandroNPC()

	local savedRootText = NormalizeMenuText(LLRCA_DB.rootMenuOption or "")
	local savedRoot = string.lower(savedRootText)

	local storedLandroRoot = savedRoot == "landro longshot"
		and (LLRCA_DB.rootIsNPC == true or LLRCA_DB.rootMenuOption ~= nil)

	-- Modern Landro dialogs use the NPC itself as the fixed root. The option
	-- "Was für Aktionen bietet Ihr an?" must not overwrite that root.
	local landroNPCMode = LLRCA_DB.rootIsNPC == true
		or npcIsLandro == true
		or storedLandroRoot
		or IsLandroStartOptionLabel(savedRootText)

	local rootActionNavigationOption = nil

	if landroNPCMode
		and rootName
		and rootOption
		and IsLandroStartOptionLabel(rootName) then

		rootActionNavigationOption = rootOption
		rootName = nil
	end

	local matchedDepth = Core.MatchOpenGossipContext and Core.MatchOpenGossipContext(options) or nil
    -- A recorded option selection is stronger evidence than a menu-label set:
    -- different Landro branches can expose overlapping or even identical labels.
    -- Honor the selected transition before treating the incoming dialog as a
    -- newly opened root menu; the generic navigation option is handled below as
    -- a context-preserving transition.
    local hasPendingTransition = Core.pendingSelection ~= nil
    local knownLandroRootDialog = not hasPendingTransition
        and LLRCA_DB.rootIsNPC == true and matchedDepth == 1
    local freshLandroRootDialog = not rootName and not hasPendingTransition and (
        knownLandroRootDialog
        or (#Core.activeMenuContext == 0 and (
            npcIsLandro == true
            or (npcIsLandro == nil and storedLandroRoot and #options > 0)
        ))
    )

	-- Automatically leave Landro's welcome dialog. Do not learn this page as
	-- the root branch; the real action menu is shown only after selecting it.
	if landroNPCMode and rootActionNavigationOption then
		local rootActionID = rootActionNavigationOption.gossipOptionID
			or rootActionNavigationOption.id

		if rootActionID ~= nil
			and C_GossipInfo
			and C_GossipInfo.SelectOption then

			Core.pendingSelection = nil
			Core.lastSelectedMenuContext = nil
			Core.pendingSelectionSerial =
				(tonumber(Core.pendingSelectionSerial) or 0) + 1

			EnsureLandroNPCRoot()

			-- Capture the transition before asking WoW to change the dialog.
			CaptureGossipSelection(rootActionID)

			if Core.pendingSelection then
				Core.pendingSelection.ignoredNavigation = true
			end

			C_GossipInfo.SelectOption(rootActionID)
			return
		end
	end

    if rootName then
        -- Legacy client/dialog variant has a separate fixed root option.
        LLRCA_DB.rootIsNPC = nil
        Core.activeMenuContext = {}
        Core.lastSelectedMenuContext = nil
        Core.pendingSelectionSerial = Core.pendingSelectionSerial + 1
        Core.pendingSelection = nil
        if Core.State.running then Core.State.pathIndex = 1 end
        DetectFixedRootOption(options)
    elseif freshLandroRootDialog then
        -- A fresh Landro root takes precedence over a stale selection snapshot
        -- from the previous iteration, keeping the learned path intact.
        Core.pendingSelection = nil
        Core.lastSelectedMenuContext = nil
        Core.pendingSelectionSerial = Core.pendingSelectionSerial + 1
        EnsureLandroNPCRoot()
        if Core.State.running then Core.State.pathIndex = LLRCA_DB.rootIsNPC and 2 or 1 end
    elseif Core.pendingSelection then
        resolvedPendingTransition = true
        -- Navigation-only options (e.g. "other actions") expose the real menu
        -- but are intentionally not part of the configured route context.
		if Core.pendingSelection.ignoredNavigation then
			Core.activeMenuContext = Core.CopyPath(Core.pendingSelection.parentContext)
			resumeConfiguredRouteAfterNavigation = true
		elseif Core.State.running and type(Core.lastSelectedMenuContext) == "table" then
            Core.activeMenuContext = Core.CopyPath(Core.lastSelectedMenuContext)
        else
            Core.activeMenuContext = Core.CopyPath(Core.pendingSelection.parentContext)
            table.insert(Core.activeMenuContext, Core.pendingSelection.name)
        end
        Core.pendingSelectionSerial = Core.pendingSelectionSerial + 1
        Core.pendingSelection = nil
        Core.lastSelectedMenuContext = nil
    elseif #Core.activeMenuContext == 0 then
        -- Fallback when the NPC identity is unavailable and no stored branch
        -- matched the currently visible options.
        if npcIsLandro == true or (npcIsLandro == nil and storedLandroRoot and #options > 0) then
            EnsureLandroNPCRoot()
        end
    end

    -- If the exact root-option variant was used, preserve its empty context for
    -- the parent-option dialog. Otherwise the live context contains Landro or
    -- the chain of selected child options.
    Core.HandleGossipOptions(options)

    if resolvedPendingTransition and not Core.State.running
        and Core.learningTargetIndex and pendingLearningTargetIndex then
        local currentContext = Core.activeMenuContext or {}
        if not ContextMatchesRoutePrefix(currentContext, LLRCA_DB.path or {}, #currentContext) then
            -- The just-opened dialog belongs to the path that was selected before
            -- the user edited the dropdown. Re-evaluate from this now-live dialog
            -- so the root/"other actions" fallback can bring us onto the latest path.
            ProcessLearningPathRequest(pendingLearningTargetIndex, learningRequestSerial)
            return
        end
    end

	-- Replaying a known path after reopening Landro does not require the user
	-- to press Start. Resume only after a navigation-only transition has
	-- landed back at Landro's actual root context.
	local currentContext = Core.activeMenuContext or {}
	local atLandroRoot = #currentContext == 1
		and string.lower(NormalizeMenuText(currentContext[1])) == "landro longshot"

	if resumeConfiguredRouteAfterNavigation
		and atLandroRoot
		and not Core.State.running
		and not Core.learningTargetIndex
		and type(LLRCA_RequestLearnPath) == "function" then

		local path = LLRCA_DB.path or {}
		local targetIndex = 1

		for index = 2, #path do
			if NormalizeMenuText(path[index] or "") == "" then
				break
			end
			targetIndex = index
		end

		if targetIndex >= 2 then
			LLRCA_RequestLearnPath(targetIndex)
			return
		end
	end

    -- Legacy variant only: automatically open its separate fixed root option
    -- once so the child branch can be learned. Current Landro dialogs skip this.
    if rootName and not Core.State.running then
        local rootBranchLearned = LLRCA_IsMenuBranchLearnedForStep and LLRCA_IsMenuBranchLearnedForStep(2)
        local rootBranchOptions = LLRCA_GetMenuOptionsForStep and LLRCA_GetMenuOptionsForStep(2) or {}
        if not rootBranchLearned or #rootBranchOptions == 0 then
            local rootOptionID = rootOption and (rootOption.gossipOptionID or rootOption.id)
            if rootOptionID and C_GossipInfo and C_GossipInfo.SelectOption then
                CaptureGossipSelection(rootOptionID)
                C_GossipInfo.SelectOption(rootOptionID)
                return
            end
        end
    end

    if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end
end

gossipFrame:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_CLOSED" then
        gossipReadSerial = gossipReadSerial + 1
        local closeSerial = gossipReadSerial
        -- Do not clear the visible-option map or current parent here. The
        -- secure post-hook for C_GossipInfo.SelectOption can run after this
        -- event, and needs both values to capture the selected child correctly.
        -- Clear only if no next dialog and no selection arrives shortly after.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.18, function()
                if gossipReadSerial ~= closeSerial then return end
                -- Landro's terminal action opens the code-entry popup instead
                -- of another gossip dialog. Record an observed empty child
                -- branch so Start can distinguish a leaf from an unlearned menu.
                if Core.IsCodeEntryPopupOpen() then
                    -- A route edit may be cancelling the old endpoint popup. Do
                    -- not resolve it as a completed leaf or clear the new learning
                    -- target while that cancellation is in progress.
                    if Core.learningPopupCancelPending then return end
                    -- A manually selected, off-route step-2 action may open the
                    -- same key popup as a valid leaf. The popup watcher cancels
                    -- this case; never persist it as the configured route endpoint.
                    if Core.wrongRootSelectionPending then return end
                    -- Resolve the selected leaf BEFORE recording an empty branch.
                    -- Otherwise an early popup event can overwrite its parent's
                    -- child list, causing the chosen row to be cleared on refresh.
                    Core.ResolveCodeEntryEndpointContext()
                    Core.MarkCodeEndpointContext()
                    Core.ObserveGossipOptions({}, Core.activeMenuContext)
                    if Core.learningTargetIndex and #Core.activeMenuContext >= Core.learningTargetIndex then
                        Core.CompleteLearningRequest()
                        if LLRCA_RefreshPathRows then LLRCA_RefreshPathRows() end
                        if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end
                        print("[LLRCA] " .. LLRCA_L.CODE_ENDPOINT_CONFIRMED)
                    end
                    return
                end
                if Core.pendingSelection == nil then
                    Core.activeMenuContext = {}
                    Core.visibleOptionNamesByID = {}
                    Core.visibleOptionNamesByIndex = {}
                end
            end)
        end
        return
    end

	gossipReadSerial = gossipReadSerial + 1
	local serial = gossipReadSerial

	if C_Timer and C_Timer.After then
		C_Timer.After(0.01, function()
			if gossipReadSerial ~= serial then return end

			-- Erst nach dem Auswahl-Callback den neuen Dialog verarbeiten.
			Core.ProcessCurrentGossipOptions()

			-- Anschließend prüfen, ob die Optionen inzwischen aktualisiert sind.
			C_Timer.After(0.15, function()
				if gossipReadSerial ~= serial then return end
				Core.ProcessCurrentGossipOptions()
			end)
		end)
	else
		Core.ProcessCurrentGossipOptions()
	end
end)

--------------------------------------------------
