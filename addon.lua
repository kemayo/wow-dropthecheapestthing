local ItemPrice = LibStub("ItemPrice-1.1")

local core = LibStub("AceAddon-3.0"):NewAddon("DropTheCheapestThing", "AceEvent-3.0", "AceBucket-3.0")

local db, iterate_bags, slot_sorter, copper_to_pretty_money, encode_bagslot, decode_bagslot, pretty_bagslot_name, drop_bagslot, add_junk_to_tooltip, link_to_id, item_value

local junk_slots = {}
local slot_contents = {}
local slot_counts = {}
local slot_values = {}
local slot_valuesources = {}

core.junk_slots = junk_slots
core.slot_contents = slot_contents
core.slot_counts = slot_counts
core.slot_values = slot_values
core.slot_valuesources = slot_valuesources
core.events = LibStub("CallbackHandler-1.0"):New(core)

function core:OnInitialize()
	db = LibStub("AceDB-3.0"):New("DropTheCheapestThingDB", {
		profile = {
			threshold = 0, -- items above this quality won't even be considered
			always_consider = {},
			never_consider = {},
			auction = false,
			auction_threshold = 1,
		},
	})
	self.db = db
	self:RegisterBucketEvent("BAG_UPDATE", 0.5)
end

function item_value(item, force_vendor)
	local vendor = ItemPrice:GetPrice(item) or 0
	if db.profile.auction and GetAuctionBuyout and not force_vendor then
		local auction = GetAuctionBuyout(item) or 0
		if auction > vendor then
			return auction, 'auction'
		end
	end
	return vendor, 'vendor'
end
core.item_value = item_value

function core:BAG_UPDATE(updated_bags)
	table.wipe(junk_slots)
	table.wipe(slot_contents)
	table.wipe(slot_counts)
	table.wipe(slot_values)
	table.wipe(slot_valuesources)

	local total = 0

	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			local itemid = link_to_id(link)
			local _, count, _, quality = GetContainerItemInfo(bag, slot)
			-- quality_ is -1 if the item requires "special handling"; stackable, quest, whatever.
			-- I'm not actually sure how best to handle this; it's not really a problem with greys, but
			-- whites and above could have quest-item issues. Though I suppose quest items don't have
			-- vendor values, so...
			if quality == -1 then quality = select(3, GetItemInfo(link)) end
			if (not db.profile.never_consider[itemid]) and ((db.profile.always_consider[itemid]) or (quality and quality <= db.profile.threshold)) then
				local value, source = item_value(itemid, quality < db.profile.auction_threshold)
				if value and value > 0 then
					local bagslot = encode_bagslot(bag, slot)
					table.insert(junk_slots, bagslot)
					slot_contents[bagslot] = link
					slot_counts[bagslot] = count
					slot_values[bagslot] = value * count
					slot_valuesources[bagslot] = source
					total = total + slot_values[bagslot]
				end
			end
		end
	end
	
	table.sort(junk_slots, slot_sorter)
	self.events:Fire("Junk_Update", #junk_slots, total)
end

-- The rest is utility functions used above:

function slot_sorter(a,b) return slot_values[a] < slot_values[b] end

function link_to_id(link) return link and tonumber(string.match(link, "item:(%d+)")) end -- "item" because we only care about items, duh
core.link_to_id = link_to_id

function pretty_bagslot_name(bagslot, show_name, show_count, force_count)
	if not bagslot or not slot_contents[bagslot] then return "???" end
	if show_name == nil then show_name = true end
	if show_count == nil then show_count = true end
	local link = slot_contents[bagslot]
	local name = link:gsub("[%[%]]", "")
	local max = select(8, GetItemInfo(link))
	return (show_name and link:gsub("[%[%]]", "") or '') ..
		((show_name and show_count) and ' ' or '') ..
		((show_count and (force_count or max > 1)) and (slot_counts[bagslot] .. '/' .. max) or '')
end
core.pretty_bagslot_name = pretty_bagslot_name

function copper_to_pretty_money(c)
	if c >= 10000 then
		return ("|cffffffff%d|r|cffffd700g|r|cffffffff%d|r|cffc7c7cfs|r|cffffffff%d|r|cffeda55fc|r"):format(c/10000, (c/100)%100, c%100)
	elseif c >= 100 then
		return ("|cffffffff%d|r|cffc7c7cfs|r|cffffffff%d|r|cffeda55fc|r"):format((c/100)%100, c%100)
	else
		return ("|cffffffff%d|r|cffeda55fc|r"):format(c%100)
	end
end
core.copper_to_pretty_money = copper_to_pretty_money

function add_junk_to_tooltip(tooltip)
	if #junk_slots == 0 then
		tooltip:AddLine("Nothing")
		return
	else
		local total = 0
		for _, bagslot in ipairs(junk_slots) do
			tooltip:AddDoubleLine(pretty_bagslot_name(bagslot), copper_to_pretty_money(slot_values[bagslot]) ..
				(db.profile.auction and (' '..slot_valuesources[bagslot]:sub(1,1)) or ''),
				nil, nil, nil, 1, 1, 1)
			total = total + slot_values[bagslot]
		end
		tooltip:AddDoubleLine(" ", "Total: " .. copper_to_pretty_money(total), nil, nil, nil, 1, 1, 1)
	end
end
core.add_junk_to_tooltip = add_junk_to_tooltip

function encode_bagslot(bag, slot) return (bag*100) + slot end
function decode_bagslot(int) return math.floor(int/100), int % 100 end
core.encode_bagslot = encode_bagslot
core.decode_bagslot = decode_bagslot

function drop_bagslot(bagslot, sell_only)
	local bag, slot = decode_bagslot(bagslot)
	if not (bagslot and slot_contents[bagslot]) then
		return DEFAULT_CHAT_FRAME:AddMessage("DropTheCheapestThing Error: Nothing found in requested slot. Aborting.", 1, 0, 0)
	end
	if slot_contents[bagslot] ~= GetContainerItemLink(bag, slot) then
		return DEFAULT_CHAT_FRAME:AddMessage(("DropTheCheapestThing Error: Expected %s in bag slot, found %s instead. Aborting."):format(slot_contents[bagslot], GetContainerItemLink(bag, slot)), 1, 0, 0)
	end
	if CursorHasItem() then
		return DEFAULT_CHAT_FRAME:AddMessage(("DropTheCheapestThing Error: Can't delete/sell items while an item is on the cursor. Aborting."):format(slot_contents[bagslot], GetContainerItemLink(bag, slot)), 1, 0, 0)
	end
	if sell_only and not MerchantFrame:IsVisible() then
		return DEFAULT_CHAT_FRAME:AddMessage(("DropTheCheapestThing Error: Can't sell items while not at a merchant. Aborting."):format(slot_contents[bagslot], GetContainerItemLink(bag, slot)), 1, 0, 0)
	end

	if MerchantFrame:IsVisible() then
		DEFAULT_CHAT_FRAME:AddMessage("Selling "..pretty_bagslot_name(bagslot).." for "..copper_to_pretty_money(slot_values[bagslot]))
		UseContainerItem(bag, slot)
	else
		DEFAULT_CHAT_FRAME:AddMessage("Dropping "..pretty_bagslot_name(bagslot).." worth "..copper_to_pretty_money(slot_values[bagslot]))
		PickupContainerItem(bag, slot)
		DeleteCursorItem()
	end
end
core.drop_bagslot = drop_bagslot

