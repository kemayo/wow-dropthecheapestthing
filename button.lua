local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")
local module = core:NewModule("Merchant")

local db

function module:OnInitialize()
	self.db = core.db:RegisterNamespace("Merchant", {
		profile = {
			button = true,
			auto = false,
		},
	})
	db = self.db

	local config = core:GetModule("Config", true)
	if config then
		config.options.plugins.merchant = {
			merchant = {
				type = "group",
				name = "Merchant",
				get = function(info) return db.profile[info[#info]] end,
				set = function(info, v) db.profile[info[#info]] = v end,
				args = {
					button = {
						type = "toggle",
						name = "Show button",
						desc = "Show the 'sell all' button on the merchant frame.",
						order = 10,
					},
					auto = {
						type = "toggle",
						name = "Auto-sell",
						desc = "Automatically sell all 'junk' items when you visit a merchant.",
						order = 20,
					},
				},
			},
		}
	end
end

local button_size = 32

local button = CreateFrame("Button", nil, MerchantFrame)
button:SetWidth(button_size)
button:SetHeight(button_size)
button:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -44, -38)
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
	core.add_junk_to_tooltip(GameTooltip, core.sell_slots)
	GameTooltip:AddLine("|cffeda55fClick|r to sell everything.", 0.2, 1, 0.2, 1)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

button:SetScript("OnClick", function()
	for _, bagslot in ipairs(core.sell_slots) do
		core.drop_bagslot(bagslot, true)
	end
	button:Disable()
end)

button:Hide()

local function update_button()
	if db.profile.button then
		button:Show()
		if #core.sell_slots > 0 then
			button:Enable()
		else
			button:Disable()
		end
	else
		button:Hide()
	end
end

core.RegisterCallback("Button", "Junk_Update", update_button)

core.RegisterCallback("Button", "Merchant_Open", function()
	update_button()
	if db.profile.auto then
		button:Click()
	end
end)
