local frame = CreateFrame("Frame", "LLRCA_MainFrame", UIParent, "BasicFrameTemplateWithInset")

frame:SetSize(560, 860)

frame:SetPoint(LLRCA_DB.framePos.point, UIParent, LLRCA_DB.framePos.relativePoint, LLRCA_DB.framePos.x, LLRCA_DB.framePos.y)

frame:Hide()

LLRCA_Frame = frame

table.insert(UISpecialFrames, "LLRCA_MainFrame")

local PAD = 20

local WIDTH = 
frame:GetWidth()
 - (PAD * 2)

frame:SetMovable(true)

frame:EnableMouse(true)

frame:RegisterForDrag("LeftButton")

frame:SetScript("OnDragStart", function(self)
	self:StartMoving()
end
)

frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()

	local point, _, relativePoint, x, y = 
self:GetPoint()

	LLRCA_DB.framePos = {

		point = point,

		relativePoint = relativePoint,

		x = x,

		y = y,
	}
end
)

----- TITLE

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")

title:SetPoint("TOP", 0, -10)

title:SetText("Landro Automated Random-Code-Generator")

---

-- CODE COUNT

local countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

countLabel:SetPoint("TOPLEFT", 20, -35)

countLabel:SetText(LLRCA_L.CODES
)

local countHelp = 
frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

countHelp:SetWidth(360)

countHelp:SetJustifyH("LEFT")

countHelp:SetPoint("TOPLEFT", 20, -60)

countHelp:SetText(LLRCA_L.CODES_DESC
)

local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")

box:SetSize(WIDTH, 34)

box:SetPoint("TOPLEFT", 20, -82)

box:SetNumeric(true)

box:SetNumber(LLRCA_DB.codeCount or LLRCA_DEFAULTS.codeCount)

box:SetAutoFocus(false)

box:SetMaxLetters(5)

box:SetScript("OnEditFocusLost", function(self)
	local value = tonumber(self:GetText()) or LLRCA_DEFAULTS.codeCount

	value = math.floor(value)

	if value < 1 then
		value = 1
	elseif value > 10000 then
		value = 10000
	end

	LLRCA_DB.codeCount = value

	self:SetNumber(value)

	self:ClearFocus()
end)

LLRCA_CountBox = box

--------------------------------------------------
-- CODE LENGTH
--------------------------------------------------

local lengthLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

lengthLabel:SetPoint("TOPLEFT", 20, -125)

lengthLabel:SetText(LLRCA_L.CODE_LENGTH)

local lengthHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

lengthHelp:SetWidth(360)

lengthHelp:SetJustifyH("LEFT")

lengthHelp:SetPoint("TOPLEFT", 20, -150)

lengthHelp:SetText(LLRCA_L.CODE_LENGTH_DESC)

local lengthBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")

lengthBox:SetSize(WIDTH, 34)

lengthBox:SetPoint("TOPLEFT", 20, -172)

lengthBox:SetNumeric(true)

lengthBox:SetNumber(LLRCA_DB.codeLength or LLRCA_DEFAULTS.codeLength)

lengthBox:SetAutoFocus(false)

lengthBox:SetMaxLetters(2)

lengthBox:SetScript("OnEditFocusLost", function(self)
	local value = tonumber(self:GetText()) or LLRCA_DEFAULTS.codeLength

	value = math.floor(value)

	if value < 5 then
		value = 5
	elseif value > 50 then
		value = 50
	end

	LLRCA_DB.codeLength = value

	self:SetNumber(value)

	self:ClearFocus()
end)

LLRCA_LengthBox = lengthBox

--------------------------------------------------
-- GOSSIP PATH
--------------------------------------------------

---

-- GOSSIP PATH

local pathLabel = 
frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

pathLabel:SetPoint("TOPLEFT", 20, -235)

pathLabel:SetText(LLRCA_L.PATH)

local pathHelp = 
frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

pathHelp:SetWidth(360)

pathHelp:SetJustifyH("LEFT")

pathHelp:SetPoint("TOPLEFT", 20, -260)

pathHelp:SetText(LLRCA_L.PATH_DESC
)

local function CreatePathBox(y, index)
	local label = 
frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

	label:SetPoint("TOPLEFT", 20, y + 20)

	label:SetText(LLRCA_L_LABLE_MENUPOINT .. " " .. index
)

	local e = 
CreateFrame("EditBox", nil, frame, "InputBoxTemplate")

	e:SetSize(WIDTH, 34)

	e:SetPoint("TOPLEFT", 20, y)

	e:SetAutoFocus(false)

	e:SetText(LLRCA_DB.path[index] or ""
)

	e:SetScript("OnTextChanged", function(self)
		LLRCA_DB.path[index] = 
self:GetText()
	end
)

	return e
end

LLRCA_Path1 = CreatePathBox(-330, 1)

LLRCA_Path2 = CreatePathBox(-405, 2)

LLRCA_Path3 = CreatePathBox(-480, 3)

--------------------------------------------------
-- STATUS
--------------------------------------------------

local statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

statusLabel:SetPoint("TOPLEFT", 20, -545)

statusLabel:SetText("Status:")

local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

statusText:SetWidth(WIDTH - 140)

statusText:SetJustifyH("LEFT")

statusText:SetPoint("TOPLEFT", 110, -545)

statusText:SetText(LLRCA_L.NOT_STARTED)

LLRCA_StatusText = statusText

--------------------------------------------------

local progressLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

progressLabel:SetPoint("TOPLEFT", 20, -575)

progressLabel:SetText("Code:")

local progressText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

progressText:SetPoint("TOPLEFT", 110, -575)

progressText:SetText("-")

LLRCA_ProgressText = progressText

--------------------------------------------------

local nextLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

nextLabel:SetPoint("TOPLEFT", 20, -610)

nextLabel:SetText(LLRCA_L_NEXT_CODE .. ":")

local nextCode = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")

nextCode:SetWidth(WIDTH - 20)

nextCode:SetJustifyH("LEFT")

nextCode:SetPoint("TOPLEFT", 20, -632)

nextCode:SetText("-")

LLRCA_NextCodeText = nextCode

--------------------------------------------------

local lastLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

lastLabel:SetPoint("TOPLEFT", 20, -690)

lastLabel:SetText(LLRCA_L_LAST_CODE .. ":")

local lastCode = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")

lastCode:SetWidth(WIDTH - 20)

lastCode:SetJustifyH("LEFT")

lastCode:SetPoint("TOPLEFT", 20, -712)

lastCode:SetText("-")

LLRCA_LastCodeText = lastCode

--------------------------------------------------
-- NEXT COPY BUTTON
--------------------------------------------------

local nextCopy = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

nextCopy:SetSize(55, 22)

nextCopy:SetPoint("LEFT", nextLabel, "RIGHT", 15, 0)

nextCopy:SetText(LLRCA_L_COPY)

nextCopy:Hide()

LLRCA_NextCopyButton = nextCopy

--------------------------------------------------
-- LAST COPY BUTTON
--------------------------------------------------

local lastCopy = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

lastCopy:SetSize(55, 22)

lastCopy:SetPoint("LEFT", lastLabel, "RIGHT", 15, 0)

lastCopy:SetText(LLRCA_L_COPY)

lastCopy:Hide()

LLRCA_LastCopyButton = lastCopy

--------------------------------------------------
-- COPY WINDOW
--------------------------------------------------

local copyFrame = CreateFrame("Frame", "LLRCA_CopyFrame", UIParent, "BasicFrameTemplateWithInset")

copyFrame:SetSize(460, 130)

copyFrame:SetPoint("CENTER")

copyFrame:SetFrameStrata("DIALOG")

copyFrame:Hide()

LLRCA_CopyFrame = copyFrame

table.insert(UISpecialFrames, "LLRCA_CopyFrame")

local title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")

title:SetPoint("TOP", 0, -10)

title:SetText(LLRCA_L_COPY_TITLE)

local edit = CreateFrame("EditBox", nil, copyFrame, "InputBoxTemplate")

edit:SetSize(400, 32)

edit:SetPoint("TOP", 0, -45)

edit:SetAutoFocus(false)

LLRCA_CopyEdit = edit

edit:SetScript("OnEscapePressed", function()
	LLRCA_CopyEdit:SetText("")

	copyFrame:Hide()
end
)

edit:SetScript("OnEnterPressed", function(self)
	self:ClearFocus()
end
)

edit:SetScript("OnEnterPressed", function(self)
	self:ClearFocus()
end
)

local close = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")

close:SetSize(120, 26)

close:SetPoint("BOTTOM", 0, 15)

close:SetText(CLOSE)

close:SetScript("OnClick", function()
	LLRCA_CopyEdit:SetText("")

	copyFrame:Hide()
end
)

LLRCA_NextCopyButton:SetScript("OnClick", function()
	if not LLRCA_CurrentCode then
		return
	end

	LLRCA_CopyEdit:SetText(LLRCA_CurrentCode)

	LLRCA_CopyEdit:SetFocus()

	LLRCA_CopyEdit:HighlightText()

	LLRCA_CopyFrame:Show()

	LLRCA_CopyFrame:Raise()

	LLRCA_CopyEdit:SetFocus()

	LLRCA_CopyEdit:HighlightText()
end
)

LLRCA_LastCopyButton:SetScript("OnClick", function()
	if not LLRCA_PreviousCode then
		return
	end

	LLRCA_CopyEdit:SetText(LLRCA_PreviousCode)

	LLRCA_CopyEdit:SetFocus()

	LLRCA_CopyEdit:HighlightText()

	LLRCA_CopyFrame:Show()

	LLRCA_CopyFrame:Raise()

	LLRCA_CopyEdit:SetFocus()

	LLRCA_CopyEdit:HighlightText()
end
)

---

local reset = 
CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

reset:SetSize(WIDTH, 30)

reset:SetPoint("BOTTOMLEFT", PAD, 80)

reset:SetText(LLRCA_L_DEFAULT)

reset:SetScript("OnClick", function()
	LLRCA_DB.codeCount = LLRCA_DEFAULTS.codeCount

	LLRCA_CountBox:SetNumber(LLRCA_DEFAULTS.codeCount)

	LLRCA_DB.codeLength = LLRCA_DEFAULTS.codeLength

	LLRCA_LengthBox:SetNumber(LLRCA_DEFAULTS.codeLength)

	for i, v in ipairs(LLRCA_DEFAULTS.path)
 do
		LLRCA_DB.path[i] = v
	end

	LLRCA_Path1:SetText(LLRCA_DB.path[1])

	LLRCA_Path2:SetText(LLRCA_DB.path[2])

	LLRCA_Path3:SetText(LLRCA_DB.path[3])
end
)

--------------------------------------------------
-- START BUTTON
--------------------------------------------------

local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

btn:SetSize(WIDTH, 40)

btn:SetPoint("BOTTOMLEFT", PAD, 30)

btn:SetText(LLRCA_L.START)

LLRCA_StartButton = btn
