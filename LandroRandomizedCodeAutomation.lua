local addonName = ...

local Codes = {}

local UsedCodes = {}

local State = {

	running = false,

	current = 1,

	total = 0,

	lastCode = nil,
}
local popupOpen = false

LLRCA_CurrentCode = nil

LLRCA_PreviousCode = nil

local function UpdateStatus(message)
	if not LLRCA_StatusText then
		return
	end

	local total = State.total or 0

	local current = "-"

	local code = "-"

	local previous = "-"

	if total > 0 then
		current = State.current

		code = Codes[State.current] or "-"

		previous = State.lastCode or "-"
	end

	LLRCA_StatusText:SetText(message)

	LLRCA_ProgressText:SetText(current .. " / " .. total)

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

local function GetNextUniqueCode()
	while true do
		local code = GenerateCode()

		if not UsedCodes[code] then
			UsedCodes[code] = true

			return code
		end
	end
end

local function GenerateCodes()
	wipe(Codes)

	wipe(UsedCodes)

	State.current = 1

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

	State.total = amount

	Codes[1] = GetNextUniqueCode()
end

--------------------------------------------------
-- START
--------------------------------------------------

LLRCA_StartButton:SetScript("OnClick", function()
	if not State.running then
		GenerateCodes()

		State.running = true

		LLRCA_StartButton:SetText(LLRCA_L.STOP)

		UpdateStatus(LLRCA_L.TALK)
	else
		State.running = false

		wipe(Codes)

		State.current = 1

		LLRCA_StartButton:SetText(LLRCA_L.START)

		UpdateStatus(LLRCA_L.STOPPED)
	end
end)

--------------------------------------------------
-- GOSSIP
--------------------------------------------------

local frame = CreateFrame("Frame")

frame:RegisterEvent("GOSSIP_SHOW")

frame:SetScript("OnEvent", function()
	if not State.running then
		return
	end

	local options = C_GossipInfo.GetOptions()

	if not options then
		return
	end

	for _, option in ipairs(options) do
		local txt = string.lower(option.name or "")

		local match = false

		for _, entry in ipairs(LLRCA_DB.path) do
			if string.find(txt, string.lower(entry)) then
				match = true

				break
			end
		end

		if match then
			print("[STH] klick -> " .. txt)

			C_GossipInfo.SelectOption(option.gossipOptionID)

			return
		end
	end
end)

--------------------------------------------------
-- POPUP WATCHER
--------------------------------------------------

local watcher = CreateFrame("Frame")

local waitingForAccept = false

watcher:SetScript("OnUpdate", function()
	if not State.running then
		return
	end

	if not StaticPopup1 then
		return
	end

	--------------------------------------------------
	-- OPEN
	--------------------------------------------------

	if StaticPopup1:IsShown() and not popupOpen then
		popupOpen = true

		UpdateStatus(LLRCA_L.WAIT .. "...")

		if StaticPopup1EditBox then
			local code = Codes[State.current]

			StaticPopup1EditBox:SetText(code)

			UpdateStatus(LLRCA_L.WAIT .. "...")

			waitingForAccept = true

			C_Timer.After(0.5, function()
				if not waitingForAccept then
					return
				end

				if not StaticPopup1 then
					return
				end

				if not StaticPopup1:IsShown() then
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

	if popupOpen and not StaticPopup1:IsShown() then
		popupOpen = false
		waitingForAccept = false

		State.current = State.current + 1

		State.lastCode = Codes[State.current - 1]

		if State.current <= (State.total or 0) then
			Codes[State.current] = GetNextUniqueCode()
		end

		if State.current > (State.total or 0) then
			State.running = false

			wipe(Codes)

			State.current = 1

			LLRCA_StartButton:SetText(LLRCA_L.START)

			UpdateStatus(LLRCA_L.FINISHED)

			return
		end

		UpdateStatus(LLRCA_L.TALK)
	end
end)

--------------------------------------------------
-- SLASH
--------------------------------------------------

SLASH_STH1 = "/sth"

SlashCmdList.STH = function()
	print(Codes[State.current] or "none")
end
