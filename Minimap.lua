local b = CreateFrame("Button", "LLRCA_Minimap", Minimap)

b:SetFrameStrata("MEDIUM")

b:SetSize(31, 31)

local function UpdatePosition()
	local angle = math.rad(LLRCA_DB.minimapAngle)

	local radius = 102

	local x = math.cos(angle) * radius

	local y = math.sin(angle) * radius

	b:ClearAllPoints()

	b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

UpdatePosition()

--------------------------------------------------
-- BORDER
--------------------------------------------------

local border = b:CreateTexture(nil, "OVERLAY")

border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

border:SetSize(53, 53)

border:SetPoint("TOPLEFT")

--------------------------------------------------
-- ICON
--------------------------------------------------

local tex = b:CreateTexture(nil, "BACKGROUND")

tex:SetTexture("Interface\\Icons\\INV_Misc_Dice_01")

tex:SetSize(20, 20)

tex:SetPoint("CENTER")

tex:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")

b.texture = tex

--------------------------------------------------
-- INTERACTION
--------------------------------------------------

b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

b:RegisterForDrag("LeftButton")

b:SetScript("OnDragStart", function()
	b:SetScript("OnUpdate", function(self)
		local mx, my = Minimap:GetCenter()

		local px, py = GetCursorPosition()

		local scale = UIParent:GetScale()

		px = px / scale

		py = py / scale

		local angle = math.deg(math.atan2(py - my, px - mx))

		LLRCA_DB.minimapAngle = angle

		UpdatePosition()
	end)
end)

b:SetScript("OnDragStop", function()
	b:SetScript("OnUpdate", nil)
end)

b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

--------------------------------------------------
-- TOOLTIP
--------------------------------------------------

b:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")

	GameTooltip:AddLine(LLRCA_L.MAIN_TITLE .. " - " .. LLRCA_L.SUBTITLE, 1, 0.82, 0)
	GameTooltip:AddLine(LLRCA_L.MINIMAP_TOOLTIP_LEFT_CLICK, 0.30, 1.00, 0.30)
	GameTooltip:AddLine(LLRCA_L.MINIMAP_TOOLTIP_RIGHT_CLICK, 1.00, 0.82, 0.30)
	GameTooltip:Show()
end)

b:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

b:SetScript("OnClick", function(_, button)
	if button == "RightButton" then
		-- Route the click through the same reset operation used by the old slash command.
		if LLRCA_Core and LLRCA_Core.ResetLearning then
			LLRCA_Core.ResetLearning()
		else
			print("[LLRCA] " .. LLRCA_L.MINIMAP_RESET_NOT_READY)
		end
		return
	end

	if LLRCA_Frame:IsShown() then
		LLRCA_Frame:Hide()
	else
		LLRCA_Frame:Show()
	end
end)
