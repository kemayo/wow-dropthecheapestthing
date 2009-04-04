local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")

local button_size = 32

local button = CreateFrame("Button", nil, MerchantFrame)
button:SetWidth(button_size)
button:SetHeight(button_size)
button:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -44, -38)
button:SetFrameStrata("DIALOG")
button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

local texture = button:CreateTexture(nil, "BACKGROUND")
texture:SetTexture("Interface\\Icons\\INV_Egg_04")
texture:SetAllPoints(button)

local texture = button:CreateTexture()
texture:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
texture:SetAllPoints(button)
button:SetHighlightTexture(texture)

local texture = button:CreateTexture()
texture:SetTexture("Interface\\Icons\\INV_Egg_04")
texture:SetAllPoints(button)
texture:SetDesaturated(true)
button:SetDisabledTexture(texture)

button:SetScript("OnEnter", function()
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:AddLine("Junk To Sell")
	core.add_junk_to_tooltip(GameTooltip)
	GameTooltip:AddLine("|cffeda55fClick|r to sell everything.", 0.2, 1, 0.2, 1)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

button:SetScript("OnClick", function()
	for _, bagslot in ipairs(core.junk_slots) do
		core.drop_bagslot(bagslot, true)
	end
	button:Disable()
end)

local function update_button(event)
	if #core.junk_slots > 0 then
		button:Enable()
	else
		button:Disable()
	end
end

button:RegisterEvent("MERCHANT_SHOW")
button:SetScript("OnEvent", update_button)

core.RegisterCallback("Button", "Junk_Update", update_button)

