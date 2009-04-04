local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")
local module = core:NewModule("LDB")
local icon = LibStub("LibDBIcon-1.0", true)

local dataobject = LibStub("LibDataBroker-1.1"):NewDataObject("DropTheCheapestThing", {
	type = "data source",
	icon = "Interface\\Icons\\INV_Misc_Bag_22.blp",
	label = "Drop",
	text = "",
})

function dataobject:OnTooltipShow()
	self:AddLine("Junk To "..(MerchantFrame:IsVisible() and "Sell" or "Drop"))
	core.add_junk_to_tooltip(self)
	self:AddLine("|cffeda55fShift-Click|r to ".. (MerchantFrame:IsVisible() and "sell" or "delete") .." the cheapest item.", 0.2, 1, 0.2, 1)
end

function dataobject:OnClick(button)
	if button == "RightButton" then
		local config = core:GetModule("Config", true)
		if config then
			config:ShowConfig()
		end
	else
		if #core.junk_slots == 0 then return end
		if not IsShiftKeyDown() then return end
		core.drop_bagslot(core.junk_slots[1])
	end
end

local WHITE = "|cffffffff"
local END = "|r"

core.RegisterCallback("LDB", "Junk_Update", function(callback, junk_count, total)
	if junk_count == 0 then
		dataobject.text = ''
		return
	end
	local db = module.db.profile.text
	--dataobject.text = junk_count .. ' items, ' .. core.copper_to_pretty_money(total)
	dataobject.text = 
		((db.item or db.itemcount) and core.pretty_bagslot_name(core.junk_slots[1], db.item, db.itemcount, db.itemcount) or '') ..
		WHITE .. ((db.item and db.itemprice) and ' @ ' or '') .. END ..
		WHITE .. (db.itemprice and core.copper_to_pretty_money(core.slot_values[core.junk_slots[1]]) or '') .. END ..
		WHITE .. (((db.item or db.itemprice) and (db.junkcount or db.totalprice)) and ' : ' or '') .. END ..
		WHITE .. (db.junkcount and junk_count or '') .. END ..
		WHITE .. ((db.junkcount and db.totalprice) and ' @ ' or '') .. END ..
		WHITE .. (db.totalprice and core.copper_to_pretty_money(total) or '') .. END
end)

function module:OnInitialize()
	self.db = core.db:RegisterNamespace("LDB", {
		profile = {
			minimap = {},
			text = {
				item = false,
				itemcount = false,
				junkcount = true,
				itemprice = false,
				totalprice = true,
			},
		},
	})
	db = self.db
	if core.db.profile.ldbtext then
		db.profile.text = core.db.profile.ldbtext
		core.db.profile.ldbtext = nil
	end
	if icon then
		icon:Register("DropTheCheapestThing", dataobject, self.db.profile.minimap)
	end

	local config = core:GetModule("Config", true)
	if config then
		--[[config.options.plugins.broker = {
			broker = {
				type = "group",
				name = "Broker",
				args = { --]]
		config.options.args.general.plugins.broker = {
					minimap = {
						type = "toggle",
						name = "Show minimap icon",
						desc = "Toggle showing or hiding the minimap icon.",
						get = function() return not db.profile.minimap.hide end,
						set = function(info, v)
							local hide = not v
							db.profile.minimap.hide = hide
							if hide then
								icon:Hide("DropTheCheapestThing")
							else
								icon:Show("DropTheCheapestThing")
							end
						end,
						order = 10,
						width = "full",
						hidden = function() return not icon or not dataobject or not icon:IsRegistered("DropTheCheapestThing") end,
					},
					text = {
						type = "multiselect",
						name = "Broker Text",
						desc = "What to display as text for the broker icon.",
						get = function(info, key)
							return db.profile.text[key]
						end,
						set = function(info, key, v)
							db.profile.text[key] = v
							core:BAG_UPDATE()
						end,
						values = {
							item = "Cheapest item",
							itemcount = "Stack size of cheapest item",
							itemprice = "Value of cheapest item",
							junkcount = "Number of junk items",
							totalprice = "Total value of junk",
						},
						order = 20,
					},
				}
		--[[
			},
		}
		--]]
	end
end
