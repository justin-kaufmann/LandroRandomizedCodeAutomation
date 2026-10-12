-- Shared runtime state for the modular core. This namespace is private to the addon.
local addonName = ...
LLRCA_Core = LLRCA_Core or {}
local Core = LLRCA_Core

Core.Codes = {}
Core.UsedCodes = {}
Core.State = {
    running = false,
    current = 1,
    total = 0,
    lastCode = nil,
    pathIndex = 1,
}
Core.popupOpen = false
Core.waitingForAccept = false
Core.HandleGossipOptions = nil
Core.ProcessCurrentGossipOptions = nil
Core.learningTargetIndex = nil
Core.CopyPath = nil
Core.activeMenuContext = {}
Core.pendingSelection = nil
Core.pendingSelectionSerial = 0
-- Incremented for every user path edit. A Gossip transition recorded under an
-- older generation may finish in WoW, but must never override the latest route.
Core.learningRequestGeneration = 0
Core.learningReanchorPending = false
Core.visibleOptionNamesByID = {}
Core.visibleOptionNamesByIndex = {}
Core.lastSelectedMenuContext = nil
Core.wrongRootSelectionPending = false

LLRCA_CurrentCode = nil
LLRCA_PreviousCode = nil

function Core.UpdateStatus(message)
	if LLRCA_SetConfigControlsLocked then
		LLRCA_SetConfigControlsLocked(Core.State.running)
	end
	if not LLRCA_StatusText then
		return
	end
	LLRCA_StatusKind = nil

	local total = Core.State.total or 0

	local current = "-"

	local code = "-"

	local previous = "-"

	if total > 0 then
		current = Core.State.current

		code = Core.Codes[Core.State.current] or "-"

		previous = Core.State.lastCode or "-"
	end

	LLRCA_StatusText:SetText(message)
	if message == LLRCA_L.FINISHED then
		LLRCA_StatusText:SetTextColor(0.35, 1, 0.48)
	elseif message == LLRCA_L.STOPPED or message == LLRCA_L.NOT_STARTED then
		LLRCA_StatusText:SetTextColor(0.72, 0.74, 0.78)
	elseif string.find(message or "", LLRCA_L.WAIT or "__no_wait__", 1, true) then
		LLRCA_StatusText:SetTextColor(1, 0.78, 0.25)
	else
		LLRCA_StatusText:SetTextColor(0.35, 1, 0.48)
	end

	if message == LLRCA_L.FINISHED then
		current = total
	end
	if message == LLRCA_L.STOPPED then
        -- Stop should leave the progress readout visually empty, not at 1 / N.
        LLRCA_ProgressText:SetText("")
    else
        LLRCA_ProgressText:SetText(current .. " / " .. total)
    end

	if LLRCA_ProgressBar then
		local maximum = math.max(tonumber(total) or 0, 1)
		LLRCA_ProgressBar:SetMinMaxValues(0, maximum)
		local value = tonumber(current) or 0
		if message == LLRCA_L.FINISHED then
			value = maximum
		elseif message == LLRCA_L.STOPPED or message == LLRCA_L.NOT_STARTED then
			value = 0
		end
		LLRCA_ProgressBar:SetValue(math.max(0, math.min(value, maximum)))
	end

	LLRCA_NextCodeText:SetText(code)

	LLRCA_LastCodeText:SetText(previous)

	--------------------------------------------------
	-- COPY BUTTONS
	--------------------------------------------------

	LLRCA_CurrentCode = nil
	LLRCA_PreviousCode = nil

	if code ~= "-" then
		LLRCA_CurrentCode = code
	end

	if previous ~= "-" then
		LLRCA_PreviousCode = previous
	end

	LLRCA_NextCopyButton:SetShown(LLRCA_CurrentCode ~= nil)

	LLRCA_LastCopyButton:SetShown(LLRCA_PreviousCode ~= nil)
end

--------------------------------------------------
-- GENERATION
--------------------------------------------------

local function GenerateCode()
	local length = tonumber(LLRCA_DB.codeLength) or LLRCA_DEFAULTS.codeLength

	length = math.floor(length)

	if length < 5 then
		length = 5
	elseif length > 50 then
		length = 50
	end

	local code = {}

	for i = 1, length do
		code[i] = tostring(math.random(0, 9))
	end

	return table.concat(code)
end

function Core.GetNextUniqueCode()
	while true do
		local code = GenerateCode()

		if not Core.UsedCodes[code] then
			Core.UsedCodes[code] = true

			return code
		end
	end
end

function Core.GenerateCodes()
	wipe(Core.Codes)

	wipe(Core.UsedCodes)

	Core.State.current = 1

	local amount = tonumber(LLRCA_CountBox:GetText()) or LLRCA_DEFAULTS.codeCount

	local length = tonumber(LLRCA_LengthBox:GetText()) or LLRCA_DEFAULTS.codeLength

	length = math.floor(length)

	if length < 5 then
		length = 5
	elseif length > 50 then
		length = 50
	end

	LLRCA_DB.codeCount = amount
	LLRCA_DB.codeLength = length

	Core.State.total = amount

	Core.Codes[1] = Core.GetNextUniqueCode()
end

