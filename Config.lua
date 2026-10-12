local defaults = {
    codeCount = 100,
    codeLength = 25,
    minimapAngle = 235,
    framePos = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
    -- One fixed auto-detected root plus two initially visible configurable rows.
    -- Further rows are added on demand; no fixed path-depth cap is imposed.
    path = { "", "", "" },
}

LLRCA_DEFAULTS = defaults
LLRCA_DB = LLRCA_DB or {}

if not LLRCA_DB.codeCount then LLRCA_DB.codeCount = defaults.codeCount end
if not LLRCA_DB.codeLength then LLRCA_DB.codeLength = defaults.codeLength end
if type(LLRCA_DB.path) ~= "table" then LLRCA_DB.path = {} end
if #LLRCA_DB.path == 0 then
    LLRCA_DB.path = { "", "", "" }
end

-- Legacy path format v1 did not reserve path[1] for Landro's fixed start option.
if (tonumber(LLRCA_DB.pathFormatVersion) or 0) < 2 then
    local oldPath = LLRCA_DB.path
    local migratedPath = { "" }
    for i, value in ipairs(oldPath) do migratedPath[i + 1] = value end
    LLRCA_DB.path = migratedPath
    LLRCA_DB.pathFormatVersion = 2
    LLRCA_DB.pathMigrationPendingRootCheck = true
end

-- Version 3 introduces a parent-aware menu tree. Old values came from a flat
-- option list and therefore cannot safely be assumed to belong to the selected
-- parent. Preserve the number of rows and the root label, but clear old choices.
if (tonumber(LLRCA_DB.pathFormatVersion) or 0) < 3 then
    local oldPath = LLRCA_DB.path
    local root = LLRCA_DB.rootMenuOption or oldPath[1] or ""
    local rowCount = math.max(#oldPath, 3)
    local newPath = { root }
    for i = 2, rowCount do newPath[i] = "" end
    LLRCA_DB.path = newPath
    LLRCA_DB.pathFormatVersion = 4
    LLRCA_DB.pathMigrationPendingRootCheck = nil
end

if type(LLRCA_DB.rootMenuOption) == "string" and LLRCA_DB.rootMenuOption ~= "" then
    LLRCA_DB.path[1] = LLRCA_DB.rootMenuOption
elseif LLRCA_DB.path[1] == nil then
    LLRCA_DB.path[1] = ""
end

if type(LLRCA_DB.knownMenuOptions) ~= "table" then LLRCA_DB.knownMenuOptions = {} end
if type(LLRCA_DB.knownMenuTree) ~= "table" then LLRCA_DB.knownMenuTree = {} end
if type(LLRCA_DB.knownCodeEndpoints) ~= "table" then LLRCA_DB.knownCodeEndpoints = {} end
if (tonumber(LLRCA_DB.pathFormatVersion) or 0) < 4 then LLRCA_DB.pathFormatVersion = 4 end
if not LLRCA_DB.framePos then LLRCA_DB.framePos = defaults.framePos end
if not LLRCA_DB.minimapAngle then LLRCA_DB.minimapAngle = defaults.minimapAngle end

-- Normalize labels consistently in the UI and the event-driven menu learner.
function LLRCA_NormalizeMenuText(value)
    if type(value) ~= "string" then return "" end
    -- string.gsub returns both the transformed string and a replacement count.
    -- Parenthesize the expression so this public normalizer always returns one
    -- value; otherwise table constructors such as { NormalizeMenuText(root) }
    -- can silently append the gsub count (0) as a bogus menu-path step.
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Landro's "Habt Ihr noch andere Aktionen anzubieten?" entry is a generic
-- navigation/control option, not a real code path. It must never appear in
-- the learned tree or be treated as a submenu branch.
function LLRCA_IsIgnoredMenuOption(value)
    local text = string.lower(LLRCA_NormalizeMenuText(value))
    text = text:gsub("[%?%!%.,:;]", " "):gsub("%s+", " ")
    local ignored = {
        "habt ihr noch andere aktionen anzubieten",
        "habt ihr andere aktionen anzubieten",
        "have you any other actions to offer",
        "do you have any other actions to offer",
        "have any other actions to offer",
    }
    for _, phrase in ipairs(ignored) do
        if string.find(text, phrase, 1, true) then return true end
    end
    return false
end

-- Fold a navigation-only "other actions" submenu back into its parent route.
-- Older builds stored the actual step-2 menu under a context containing that
-- generic control entry. Re-parent it before filtering the control out; simply
-- deleting that context would discard the 21-option menu needed by the route.
local LLRCA_CONTEXT_SEPARATOR = string.char(31)
local function LLRCA_SplitContextKey(key)
    local parts = {}
    key = tostring(key or "")
    local startAt = 1
    while true do
        local found = string.find(key, LLRCA_CONTEXT_SEPARATOR, startAt, true)
        if not found then
            table.insert(parts, string.sub(key, startAt))
            break
        end
        table.insert(parts, string.sub(key, startAt, found - 1))
        startAt = found + 1
    end
    return parts
end

local remappedBranches = {}
for key, branch in pairs(LLRCA_DB.knownMenuTree) do
    if type(branch) == "table" then
        local parts = LLRCA_SplitContextKey(key)
        local parentParts, removedControl = {}, false
        for _, part in ipairs(parts) do
            if LLRCA_IsIgnoredMenuOption(part) then
                removedControl = true
            else
                table.insert(parentParts, part)
            end
        end
        if removedControl and #parentParts > 0 then
            remappedBranches[table.concat(parentParts, LLRCA_CONTEXT_SEPARATOR)] = branch
        end
    end
end
for parentKey, branch in pairs(remappedBranches) do
    -- The branch after the filtered control is the actual configurable menu.
    LLRCA_DB.knownMenuTree[parentKey] = branch
end

for key, branch in pairs(LLRCA_DB.knownMenuTree) do
    local parts = LLRCA_SplitContextKey(key)
    local hasIgnoredControl = false
    for _, part in ipairs(parts) do
        if LLRCA_IsIgnoredMenuOption(part) then
            hasIgnoredControl = true
            break
        end
    end
    if hasIgnoredControl then
        LLRCA_DB.knownMenuTree[key] = nil
    elseif type(branch) == "table" then
        local cleaned = {}
        for _, optionName in ipairs(branch) do
            if not LLRCA_IsIgnoredMenuOption(optionName) then
                table.insert(cleaned, optionName)
            end
        end
        LLRCA_DB.knownMenuTree[key] = cleaned
    end
end
local cleanedFlatOptions = {}
for _, optionName in ipairs(LLRCA_DB.knownMenuOptions) do
    if not LLRCA_IsIgnoredMenuOption(optionName) then
        table.insert(cleanedFlatOptions, optionName)
    end
end
LLRCA_DB.knownMenuOptions = cleanedFlatOptions

-- A key identifies the dialogue visible after selecting path[1..length].
-- Empty context is the NPC's initial dialog and is stored under the empty key.
function LLRCA_MenuContextKey(path, length)
    path = path or {}
    length = tonumber(length)
    if length == nil then length = #path end
    if length <= 0 then return "" end
    local parts = {}
    for i = 1, length do
        local label = LLRCA_NormalizeMenuText(path[i])
        if label == "" then return nil end
        parts[#parts + 1] = string.lower(label)
    end
    return table.concat(parts, "\31")
end

-- Return only the options visible after all previous steps in the configured
-- path. This is what makes each dropdown dependent on its parent selection.
function LLRCA_GetMenuOptionsForStep(index)
    index = tonumber(index) or 1
    if index <= 1 then return {} end
    local path = (LLRCA_DB and LLRCA_DB.path) or {}
    local key = LLRCA_MenuContextKey(path, index - 1)
    if key == nil then return {} end
    local tree = (LLRCA_DB and LLRCA_DB.knownMenuTree) or {}
    local options = tree[key]
    if type(options) ~= "table" then return {} end
    local filtered = {}
    for _, optionName in ipairs(options) do
        if not LLRCA_IsIgnoredMenuOption(optionName) then
            table.insert(filtered, optionName)
        end
    end
    return filtered
end

-- Distinguish an unvisited submenu (no tree entry yet) from a submenu that
-- was actually observed but had no further options. The UI uses this to keep
-- dependent dropdowns disabled until the corresponding dialog is learned.
function LLRCA_IsMenuBranchLearnedForStep(index)
    index = tonumber(index) or 1
    if index <= 1 then return true end
    local path = (LLRCA_DB and LLRCA_DB.path) or {}
    local key = LLRCA_MenuContextKey(path, index - 1)
    if key == nil then return false end
    local tree = (LLRCA_DB and LLRCA_DB.knownMenuTree) or {}
    return type(tree[key]) == "table"
end

function LLRCA_MenuOptionAvailable(index, value)
    local wanted = string.lower(LLRCA_NormalizeMenuText(value))
    if wanted == "" then return false end
    for _, option in ipairs(LLRCA_GetMenuOptionsForStep(index)) do
        if string.lower(LLRCA_NormalizeMenuText(option)) == wanted then return true end
    end
    return false
end


-- One-time recovery for versions that cleared path selections while a stopped
-- gossip dialog was open. A unique saved code endpoint proves the exact route
-- that previously worked. Restore only when every selectable path row is blank;
-- if multiple endpoints exist, do not guess which one the user intended.
if not LLRCA_DB.pathEndpointRecoveryV159Attempted then
    LLRCA_DB.pathEndpointRecoveryV159Attempted = true
    local path = LLRCA_DB.path or {}
    local root = LLRCA_NormalizeMenuText(LLRCA_DB.rootMenuOption or path[1] or "")
    local hasSelection = false
    for index = 2, #path do
        if LLRCA_NormalizeMenuText(path[index] or "") ~= "" then
            hasSelection = true
            break
        end
    end

    if root ~= "" and not hasSelection then
        local candidates = {}
        local rootKey = string.lower(root)
        for endpointKey, isEndpoint in pairs(LLRCA_DB.knownCodeEndpoints or {}) do
            if isEndpoint then
                local parts = LLRCA_SplitContextKey(endpointKey)
                if #parts >= 2 and string.lower(LLRCA_NormalizeMenuText(parts[1])) == rootKey then
                    table.insert(candidates, parts)
                end
            end
        end

        if #candidates == 1 then
            local endpointParts = candidates[1]
            local function FindDisplayLabel(normalized)
                normalized = string.lower(LLRCA_NormalizeMenuText(normalized))
                for _, candidate in ipairs(LLRCA_DB.knownMenuOptions or {}) do
                    if string.lower(LLRCA_NormalizeMenuText(candidate)) == normalized then return candidate end
                end
                for _, branch in pairs(LLRCA_DB.knownMenuTree or {}) do
                    if type(branch) == "table" then
                        for _, candidate in ipairs(branch) do
                            if string.lower(LLRCA_NormalizeMenuText(candidate)) == normalized then return candidate end
                        end
                    end
                end
                return normalized
            end

            local restored = { root }
            for index = 2, #endpointParts do
                restored[index] = FindDisplayLabel(endpointParts[index])
            end
            local rowCount = math.max(#path, #restored, 3)
            for index = #restored + 1, rowCount do restored[index] = "" end
            LLRCA_DB.path = restored

            -- Make every selected transition valid again. If a parent branch was
            -- overwritten by the old context bug, re-parenting above has already
            -- restored the correct branch; this only fills a missing route label.
            for index = 2, math.min(#endpointParts, #restored) do
                local parentKey = LLRCA_MenuContextKey(restored, index - 1)
                if parentKey then
                    local branch = LLRCA_DB.knownMenuTree[parentKey]
                    if type(branch) ~= "table" then branch = {} end
                    local wanted = string.lower(LLRCA_NormalizeMenuText(restored[index]))
                    local found = false
                    for _, candidate in ipairs(branch) do
                        if string.lower(LLRCA_NormalizeMenuText(candidate)) == wanted then
                            found = true
                            break
                        end
                    end
                    if not found then table.insert(branch, restored[index]) end
                    LLRCA_DB.knownMenuTree[parentKey] = branch
                end
            end

            local terminalKey = LLRCA_MenuContextKey(restored, math.min(#endpointParts, #restored))
            if terminalKey then
                LLRCA_DB.knownCodeEndpoints[terminalKey] = true
                LLRCA_DB.knownMenuTree[terminalKey] = {}
            end
            print("[LLRCA] " .. LLRCA_L.PATH_RECOVERED_FROM_KNOWN_CODE_ENDPOINT)
        end
    end
end


-- v1.5.14 endpoint evidence migration:
-- Older versions promoted an empty cached gossip branch to a code endpoint.
-- Such a marker cannot be distinguished from a genuinely observed popup after
-- the fact. Clear legacy endpoint flags ONCE while preserving all learned menu
-- branches and the user's selected route. Actual code popups re-add exact flags.
if (tonumber(LLRCA_DB.endpointEvidenceVersion) or 0) < 1 then
    LLRCA_DB.knownCodeEndpoints = {}
    LLRCA_DB.endpointEvidenceVersion = 1
end
