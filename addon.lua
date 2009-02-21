local _G = _G
local ItemPrice = LibStub("ItemPrice-1.1")

local Dropper = _G.LibStub("LibDataBroker-1.1"):NewDataObject("DropTheCheapestThing", {
	icon = "Interface\\Icons\\INV_Misc_Bag_22.blp",
	label = "Drop",
})

local iterate_bags, slot_sorter, copper_to_pretty_money, encode_bagslot, decode_bagslot, pretty_bagslot_name, drop_bagslot, add_junk_to_tooltip

local junk_slots = {}
local slot_contents = {}
local slot_counts = {}
local slot_values = {}

function Dropper:OnTooltipShow()
	self:AddLine("Junk To "..(MerchantFrame:IsVisible() and "Sell" or "Drop"))
	add_junk_to_tooltip(self)
	self:AddLine("|cffeda55fShift-Click|r to ".. (MerchantFrame:IsVisible() and "sell" or "delete") .." the cheapest item.", 0.2, 1, 0.2, 1)
end

function Dropper:OnClick()
	if #junk_slots == 0 then return end
	if not IsShiftKeyDown() then return end
	drop_bagslot(junk_slots[1])
end

local db
local frame = CreateFrame("Frame", "DropTheCheapestThing")
frame.dataobject = Dropper
frame.junk_slots = junk_slots
frame.slot_contents = slot_contents
frame.slot_counts = slot_counts
frame.slot_values = slot_values

frame:SetScript("OnEvent", function(self, event, ...)
	if self[event] then self[event](self, event, ...) end
end)
frame:RegisterEvent("ADDON_LOADED")
function frame:ADDON_LOADED(event, name)
	if name ~= "DropTheCheapestThing" then return end
	db = LibStub("AceDB-3.0"):New("DropTheCheapestThingDB", {
		profile = {
			threshold = 0, -- items above this quality won't even be considered
		},
	})
	frame:UnregisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LEAVING_WORLD")
	if IsLoggedIn() then
		self:PLAYER_ENTERING_WORLD()
	else
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	end
end
function frame:PLAYER_ENTERING_WORLD()
	frame:RegisterEvent("BAG_UPDATE")
end
function frame:PLAYER_LEAVING_WORLD()
	frame:UnregisterEvent("BAG_UPDATE")
end

-- I should throttle this -- BAG_UPDATE can be a busy event...
function frame:BAG_UPDATE(updated_bag)
	table.wipe(junk_slots)
	table.wipe(slot_contents)
	table.wipe(slot_counts)
	table.wipe(slot_values)

	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			local _, count, _, quality = GetContainerItemInfo(bag, slot)
			-- _quality_ is -1 if the item requires "special handling"; stackable, quest, whatever
			-- I'm not actually sure how best to handle this
			if quality == -1 then quality = select(3, GetItemInfo(link)) end
			if quality and quality <= db.profile.threshold then
				local value = ItemPrice:GetPrice(link)
				if value and value > 0 then
					local bagslot = encode_bagslot(bag, slot)
					table.insert(junk_slots, bagslot)
					slot_contents[bagslot] = link
					slot_counts[bagslot] = count
					slot_values[bagslot] = value * count
				end
			end
		end
	end
	
	if #junk_slots == 0 then
		Dropper.text = ''
		return
	end
	table.sort(junk_slots, slot_sorter)
	Dropper.text = pretty_bagslot_name(junk_slots[1]) .. ' ' .. copper_to_pretty_money(slot_values[junk_slots[1]])
end

-- The rest is utility functions used above:

function slot_sorter(a,b) return slot_values[a] < slot_values[b] end

function pretty_bagslot_name(bagslot)
	if not bagslot then return "???" end
	local link = slot_contents[bagslot]
	local name = link:gsub("[%[%]]", "")
	local max = select(8, GetItemInfo(link))
	if max > 1 then
		return ("%s %d/%d"):format(name, slot_counts[bagslot], max)
	else
		return name
	end
end

function copper_to_pretty_money(c)
	if c > 10000 then
		return ("%d|cffffd700g|r%d|cffc7c7cfs|r%d|cffeda55fc|r"):format(c/10000, (c/100)%100, c%100)
	elseif c > 100 then
		return ("%d|cffc7c7cfs|r%d|cffeda55fc|r"):format((c/100)%100, c%100)
	else
		return ("%d|cffeda55fc|r"):format(c%100)
	end
end

function add_junk_to_tooltip(tooltip)
	if #junk_slots == 0 then
		tooltip:AddLine("Nothing")
		return
	else
		local total = 0
		for _, bagslot in ipairs(junk_slots) do
			tooltip:AddDoubleLine(pretty_bagslot_name(bagslot), copper_to_pretty_money(slot_values[bagslot]), nil, nil, nil, 1, 1, 1)
			total = total + slot_values[bagslot]
		end
		tooltip:AddDoubleLine(" ", "Total: " .. copper_to_pretty_money(total), nil, nil, nil, 1, 1, 1)
	end
end
frame.add_junk_to_tooltip = add_junk_to_tooltip

function encode_bagslot(bag, slot) return (bag*100) + slot end
function decode_bagslot(int) return math.floor(int/100), int % 100 end
frame.encode_bagslot = encode_bagslot
frame.decode_bagslot = decode_bagslot

function drop_bagslot(bagslot, sell_only)
	local bag, slot = decode_bagslot(bagslot)
	if slot_contents[bagslot] ~= GetContainerItemLink(bag, slot) then
		DEFAULT_CHAT_FRAME:AddMessage(("DropTheCheapestThing Error: expected %s in bag slot, found %s instead. Aborting."):format(slot_contents[bagslot], GetContainerItemLink(bag, slot)), 1, 0, 0)
	end
	if CursorHasItem() then
		DEFAULT_CHAT_FRAME:AddMessage(("DropTheCheapestThing Error: Can't delete/sell items while an item is on the cursor. Aborting."):format(slot_contents[bagslot], GetContainerItemLink(bag, slot)), 1, 0, 0)
	end
	if sell_only and not MerchantFrame:IsVisible() then
		DEFAULT_CHAT_FRAME:AddMessage(("DropTheCheapestThing Error: Can't sell items while not at a merchant. Aborting."):format(slot_contents[bagslot], GetContainerItemLink(bag, slot)), 1, 0, 0)
	end

	if MerchantFrame:IsVisible() then
		DEFAULT_CHAT_FRAME:AddMessage("Selling "..pretty_bagslot_name(bagslot).." for "..copper_to_pretty_money(slot_values[junk_slots[1]]))
		UseContainerItem(bag, slot)
	else
		DEFAULT_CHAT_FRAME:AddMessage("Dropping "..pretty_bagslot_name(bagslot).." worth "..copper_to_pretty_money(slot_values[junk_slots[1]]))
		PickupContainerItem(bag, slot)
		DeleteCursorItem()
	end
end
frame.drop_bagslot = drop_bagslot

