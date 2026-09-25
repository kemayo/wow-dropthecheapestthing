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
		if not core.db.profile.mark_in_bags then return false end
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
			if core.slot_contents[bagslot] and core.db.profile.mark_in_bags then
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

-- Blizzard bags

do
	-- Our own coin texture, because Blizzard hides its JunkIcon on every refresh
	local coins = setmetatable({}, {__mode = "k"})

	local function mark(button, bag, slot)
		local junk = core.db.profile.mark_in_bags and core.slot_contents[core.encode_bagslot(bag, slot)] ~= nil
		local coin = coins[button]
		if not coin then
			if not junk then return end
			coin = button:CreateTexture(nil, "OVERLAY", nil, 6)
			coin:SetAtlas("bags-junkcoin", true)
			coin:SetPoint("TOPLEFT", 1, 0)
			coins[button] = coin
		end
		coin:SetShown(junk)
	end

	local refresh
	if _G.ContainerFrameContainer then
		-- Not using ContainerFrameUtil_EnumerateContainerFrames, as calling it would build Blizzard's cached tables from tainted code
		local frames = {_G.ContainerFrameCombinedBags}
		for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do
			table.insert(frames, frame)
		end
		local function refresh_frame(frame)
			for _, button in frame:EnumerateValidItems() do
				if button then
					mark(button, button:GetBagID(), button:GetID())
				end
			end
		end
		for _, frame in ipairs(frames) do
			hooksecurefunc(frame, "UpdateItems", refresh_frame)
		end
		function refresh()
			for _, frame in ipairs(frames) do
				refresh_frame(frame)
			end
		end
	elseif _G.ContainerFrame_Update then
		local function refresh_frame(frame)
			local name = frame:GetName()
			for i = 1, frame.size or 0 do
				local button = _G[name .. "Item" .. i]
				if button then
					mark(button, frame:GetID(), button:GetID())
				end
			end
		end
		hooksecurefunc("ContainerFrame_Update", refresh_frame)
		function refresh()
			for i = 1, NUM_CONTAINER_FRAMES do
				local frame = _G["ContainerFrame" .. i]
				if frame then
					refresh_frame(frame)
				end
			end
		end
	end

	if refresh then
		core.RegisterCallback("BlizzardBags", "Junk_Update", refresh)
	end
end
