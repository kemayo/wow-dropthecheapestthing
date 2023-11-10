local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")
local module = core:NewModule("Merchant")

local db

function module:OnInitialize()
	self.db = core.db:RegisterNamespace("Merchant", {
		profile = {
			button = true,
			blizzard = false,
			auto = false,
		},
	})
	db = self.db

	local config = core:GetModule("Config", true)
	if config then
		config.plugins.merchant = {
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
					blizzard = {
						type = "toggle",
						name = "Take over",
						desc = "Take over the built-in sell-junk button",
						order = 15,
						disabled = function() return not MerchantSellAllJunkButton end,
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

local texture

local button = CreateFrame("Button", "DropTheCheapestThingMerchantButton", MerchantFrame)
button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

texture = button:CreateTexture(nil, "BACKGROUND")
texture:SetTexture("Interface\\Icons\\INV_Egg_04")
texture:SetAllPoints(button)

texture = button:CreateTexture()
texture:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
texture:SetAllPoints(button)
button:SetHighlightTexture(texture)

texture = button:CreateTexture()
texture:SetTexture("Interface\\Icons\\INV_Egg_04")
texture:SetAllPoints(button)
texture:SetDesaturated(true)
button:SetDisabledTexture(texture)

button:SetScript("OnEnter", function()
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:AddLine(_G.SELL_ALL_JUNK_ITEMS or "Junk To Sell")
	core.add_junk_to_tooltip(GameTooltip, core.sell_slots)
	GameTooltip:AddLine("|cffeda55fClick|r to sell everything.", 0.2, 1, 0.2, 1)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

button:SetScript("OnClick", function()
	local total = 0
	for _, bagslot in ipairs(core.sell_slots) do
		local value = core.drop_bagslot(bagslot, true)
		if not value then
			break
		end
		total = total + value
	end
	if #core.sell_slots > 1 then
		DEFAULT_CHAT_FRAME:AddMessage("Total value: " .. core.copper_to_pretty_money(total))
	end
	button:Disable()
end)

button:Hide()

local function update_button()
	button:ClearAllPoints()
	if db.profile.blizzard and MerchantSellAllJunkButton then
		button:SetAllPoints(MerchantSellAllJunkButton)
		button:SetFrameLevel(MerchantSellAllJunkButton:GetFrameLevel() + 1)
	else
		button:SetSize(22, 22)
		button:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 64, -32)
	end
	if #core.sell_slots > 0 then
		button:Enable()
	else
		button:Disable()
	end
	if db.profile.button then
		button:Show()
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
