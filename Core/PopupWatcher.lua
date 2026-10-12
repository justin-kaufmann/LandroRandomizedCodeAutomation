-- Code-popup lifecycle and iteration advancement.
local Core = LLRCA_Core

-- POPUP WATCHER
--------------------------------------------------

local watcher = CreateFrame("Frame")

local lastCodePopupObserved = false

watcher:SetScript("OnUpdate", function()
    local codePopupShown = Core.IsCodeEntryPopupOpen()
    if not codePopupShown then
        lastCodePopupObserved = false
    elseif not lastCodePopupObserved then
        -- Recover from a manually selected, off-route root action before the
        -- ordinary popup handler can enter/submit a random code to that item.
        if Core.wrongRootSelectionPending then
            local wasRunning = Core.State.running
            lastCodePopupObserved = true
            Core.wrongRootSelectionPending = false
            Core.waitingForAccept = false
            Core.popupOpen = false
            Core.State.pathIndex = LLRCA_DB.rootIsNPC and 2 or 1
            Core.SetActiveContextForDepth(LLRCA_DB.rootIsNPC and 1 or 0)
            Core.pendingSelection = nil
            Core.lastSelectedMenuContext = nil
            print("[LLRCA] " .. LLRCA_L.WRONG_POPUP_DETECTED_CANCEL)

            local cancelButton = StaticPopup1Button2
            if cancelButton and cancelButton.IsVisible and cancelButton:IsVisible()
                and cancelButton.IsEnabled and cancelButton:IsEnabled() then
                cancelButton:Click()
                if wasRunning and C_Timer and C_Timer.After then
                    C_Timer.After(0.22, function()
                        if not Core.State.running then return end
                        local options = (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.GetOptions()) or {}
                        if #options > 0 then
                            -- Rebuild the live option-ID map and let the normal
                            -- handler choose "other actions" then the configured step 2.
                            Core.SetActiveContextForDepth(LLRCA_DB.rootIsNPC and 1 or 0)
                            Core.State.pathIndex = LLRCA_DB.rootIsNPC and 2 or 1
                            Core.ProcessCurrentGossipOptions()
                        else
                            Core.SetActiveContextForDepth(0)
                            Core.State.pathIndex = LLRCA_DB.rootIsNPC and 2 or 1
                            Core.UpdateStatus(LLRCA_L.TALK)
                            if LLRCA_SetLearningStatus then
                                LLRCA_SetLearningStatus(LLRCA_L.WRONG_POPUP_CANCELLED_REOPEN_LANDRO, "error")
                            end
                        end
                    end)
                elseif not wasRunning then
                    if LLRCA_SetLearningStatus then
                        LLRCA_SetLearningStatus(LLRCA_L.WRONG_POPUP_CANCELLED_PRESS_START, "error")
                    end
                else
                    Core.UpdateStatus(LLRCA_L.TALK)
                end
            else
                if wasRunning then
                    Core.State.running = false
                    LLRCA_StartButton:SetText(LLRCA_L.START)
                    Core.UpdateStatus(LLRCA_L.STOPPED)
                end
                if LLRCA_SetLearningStatus then
                    LLRCA_SetLearningStatus(LLRCA_L.WRONG_POPUP_MANUAL_CANCEL_REQUIRED, "error")
                end
            end
            return
        end

        lastCodePopupObserved = true
        local wasRunning = Core.State.running
        if not wasRunning and Core.learningPopupCancelPending then
            -- This is the OLD code popup that a path edit is closing. It must
            -- not be stored as the endpoint for the newly selected route.
            return
        end
        -- Always persist terminal-route information on the popup edge, including
        -- during an active automation run. Some clients do not emit GOSSIP_CLOSED
        -- consistently, so endpoint persistence must not depend on that event.
        -- Resolve the selected leaf first; never mark the parent dialog as terminal.
        Core.ResolveCodeEntryEndpointContext()
        local endpointSaved = Core.MarkCodeEndpointContext()
        if endpointSaved and Core.activeMenuContext and #Core.activeMenuContext > 0 then
            Core.ObserveGossipOptions({}, Core.activeMenuContext)
        end
        Core.CompleteLearningRequest()
        if LLRCA_RefreshPathRows then LLRCA_RefreshPathRows() end
        if not wasRunning then
            if LLRCA_RefreshLearningStatus then LLRCA_RefreshLearningStatus() end
            if LLRCA_SetLearningStatus then
                LLRCA_SetLearningStatus(LLRCA_L.PATH_READY, "ready")
            end
        end
    end

    if not Core.State.running then return end
    if not StaticPopup1 then return end

	--------------------------------------------------
	-- OPEN
	--------------------------------------------------

	if Core.IsCodeEntryPopupOpen() and not Core.popupOpen then
		Core.popupOpen = true

		Core.UpdateStatus(LLRCA_L.WAIT .. "...")

		if StaticPopup1EditBox then
			local code = Core.Codes[Core.State.current]

			StaticPopup1EditBox:SetText(code)

			Core.UpdateStatus(LLRCA_L.WAIT .. "...")

			Core.waitingForAccept = true

			C_Timer.After(0.5, function()
				if not Core.waitingForAccept then
					return
				end

				if not StaticPopup1 then
					return
				end

				if not Core.IsCodeEntryPopupOpen() then
					return
				end

				if StaticPopup1Button1 and StaticPopup1Button1:IsVisible() and StaticPopup1Button1:IsEnabled() then
					StaticPopup1Button1:Click()
				end
			end)
		else
		end
	end

	--------------------------------------------------
	-- CLOSED
	--------------------------------------------------

	if Core.popupOpen and not Core.IsCodeEntryPopupOpen() then
		Core.popupOpen = false
		Core.waitingForAccept = false

		Core.State.current = Core.State.current + 1

		Core.State.lastCode = Core.Codes[Core.State.current - 1]

        -- Each completed attempt starts a fresh NPC-menu traversal next time.
        -- Clear transient context but keep the learned menu tree and endpoint so
        -- the next Landro interaction always starts at the root reliably.
        Core.State.pathIndex = LLRCA_DB.rootIsNPC and 2 or 1
        Core.activeMenuContext = {}
        Core.pendingSelection = nil
        Core.lastSelectedMenuContext = nil
        Core.wrongRootSelectionPending = false
        Core.visibleOptionNamesByID = {}
        Core.visibleOptionNamesByIndex = {}

		if Core.State.current <= (Core.State.total or 0) then
			Core.Codes[Core.State.current] = Core.GetNextUniqueCode()
		end

		if Core.State.current > (Core.State.total or 0) then
			Core.State.running = false

			wipe(Core.Codes)

			Core.State.current = 1

			LLRCA_StartButton:SetText(LLRCA_L.START)

			Core.UpdateStatus(LLRCA_L.FINISHED)

			return
		end

		Core.UpdateStatus(LLRCA_L.TALK)
	end
end)

