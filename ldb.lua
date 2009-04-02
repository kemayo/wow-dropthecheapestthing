local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")

local Dropper = _G.LibStub("LibDataBroker-1.1"):NewDataObject("DropTheCheapestThing", {
	type = "data source",
	icon = "Interface\\Icons\\INV_Misc_Bag_22.blp",
	label = "Drop",
})

function Dropper:OnTooltipShow()
	self:AddLine("Junk To "..(MerchantFrame:IsVisible() and "Sell" or "Drop"))
	core.add_junk_to_tooltip(self)
	self:AddLine("|cffeda55fShift-Click|r to ".. (MerchantFrame:IsVisible() and "sell" or "delete") .." the cheapest item.", 0.2, 1, 0.2, 1)
end

function Dropper:OnClick(button)
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

core.RegisterCallback("LDB", "Junk_Update", function(callback, junk_count, total)
	if junk_count == 0 then
		Dropper.text = ''
		return
	end
	Dropper.text = junk_count .. ' items, ' .. core.copper_to_pretty_money(total)
end)

