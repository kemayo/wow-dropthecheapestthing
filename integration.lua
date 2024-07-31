local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if f[event] then return f[event](f, ...) end end)
local hooks = {}
function f:RegisterAddonHook(addon, callback)
	if C_AddOns.IsAddOnLoaded(addon) then
		callback()
	else
		hooks[addon] = callback
	end
end
function f:ADDON_LOADED(addon)
	if hooks[addon] then
		hooks[addon]()
		hooks[addon] = nil
	end
end
f:RegisterEvent("ADDON_LOADED")

-- Baganator

f:RegisterAddonHook("Baganator", function()
	-- label, id, callback(bagID, slotID, itemID, itemLink)->nil/true/false
	Baganator.API.RegisterJunkPlugin(myname, myname, function(bagID, slotID, itemID, itemLink)
		local bagslot = core.encode_bagslot(bagID, slotID)
		return core.slot_contents[bagslot] and true or false
	end)
	core.RegisterCallback("Baganator", "Junk_Update", function()
		Baganator.API.RequestItemButtonsRefresh()
	end)
end)

-- Bagnon

f:RegisterAddonHook("Bagnon", function()
	local UpdateBorder = Bagnon.Item.UpdateBorder
	local r, g, b = C_Item.GetItemQualityColor(0)

	function Bagnon.Item:UpdateBorder(...)
		-- First, do the core bagnon behavior for stuff like new-item flashing
		UpdateBorder(self, ...)
		self.JunkIcon:Hide()

		-- Now override if we have junk
		local info = self:GetInfo()
		if info and info.id then
			local bag, slot = self:GetBag(), self:GetID()
			if type(bag) ~= "number" then
				return
			end
			local bagslot = core.encode_bagslot(bag, slot)
			if core.slot_contents[bagslot] then
				self.IconGlow:SetVertexColor(r, g, b, 0.5)
				self.IconGlow:SetShown(r)
				self.JunkIcon:Show()
			end
		end
	end

	core.RegisterCallback("Bagnon", "Junk_Update", function()
		Bagnon.Frames:Update()
	end)
end)
