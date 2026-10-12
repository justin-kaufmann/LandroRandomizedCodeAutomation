-- Slash commands and initial learning status.
local Core = LLRCA_Core

--------------------------------------------------
-- SLASH
--------------------------------------------------

SLASH_STH1 = "/sth"

SlashCmdList.STH = function()
	print(Core.Codes[Core.State.current] or LLRCA_L.NO_CODE_AVAILABLE)
end

-- Initial learning hint: red until Landro and its first submenu have been learned.
if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end


-- Clear learned NPC menu data and path selections. This is invoked by the minimap
-- icon's right-click so users no longer need a slash command for this operation.
function Core.ResetLearning()
    -- Resetting learned data during automation could invalidate the active route.
    if Core.State and Core.State.running then
        local message = LLRCA_L.RESET_LEARNING_STOP_FIRST
        print("[LLRCA] " .. message)
        return false
    end

    if Core.CancelPendingLearningRequest then Core.CancelPendingLearningRequest() end
    Core.learningTargetIndex = nil
    Core.pendingSelection = nil
    Core.lastSelectedMenuContext = nil
    Core.activeMenuContext = {}
    Core.visibleOptionNamesByID = {}
    Core.visibleOptionNamesByIndex = {}
    Core.wrongRootSelectionPending = false
    Core.pendingSelectionSerial = (tonumber(Core.pendingSelectionSerial) or 0) + 1
    if Core.State then Core.State.pathIndex = 1 end

    LLRCA_DB.knownMenuTree = {}
    LLRCA_DB.knownMenuOptions = {}
    LLRCA_DB.knownCodeEndpoints = {}
    for i = 2, #(LLRCA_DB.path or {}) do LLRCA_DB.path[i] = "" end
    if LLRCA_RefreshPathRows then LLRCA_RefreshPathRows() end
    if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end
    local message = LLRCA_L.RESET_LEARNING_DONE
    print("[LLRCA] " .. message)
    return true
end
