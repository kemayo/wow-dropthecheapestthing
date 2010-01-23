local core = LibStub("AceAddon-3.0"):NewAddon("DropTheCheapestThing", "AceEvent-3.0", "AceBucket-3.0")

local debugf = tekDebug and tekDebug:GetFrame("DropTheCheapestThing")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", ...)) end end
core.Debug = Debug

local db, iterate_bags, slot_sorter, copper_to_pretty_money, encode_bagslot,
	decode_bagslot, pretty_bagslot_name, drop_bagslot, add_junk_to_tooltip,
	link_to_id, item_value, GetConsideredItemInfo, verify_slot_contents

local drop_slots = {}
local sell_slots = {}
local slot_contents = {}
local slot_counts = {}
local slot_stacksizes = {}
local slot_values = {}
local slot_weightedvalues = {}
local slot_valuesources = {}

core.drop_slots = drop_slots
core.sell_slots = sell_slots
core.slot_contents = slot_contents
core.slot_counts = slot_counts
core.slot_stacksizes = slot_stacksizes
core.slot_values = slot_values
core.slot_weightedvalues = slot_weightedvalues
core.slot_valuesources = slot_valuesources
core.events = LibStub("CallbackHandler-1.0"):New(core)

function core:OnInitialize()
	db = LibStub("AceDB-3.0"):New("DropTheCheapestThingDB", {
		profile = {
			threshold = 0, -- items above this quality won't even be considered
			sell_threshold = 0,
			always_consider = {},
			never_consider = {},
			auction = false,
			auction_threshold = 1,
			full_stacks = false,
		},
	}, DEFAULT)
	self.db = db
	self:RegisterBucketEvent("BAG_UPDATE", 2)
	self:RegisterEvent("MERCHANT_SHOW")
	self:RegisterEvent("MERCHANT_CLOSED")
	
	if MerchantFrame:IsVisible() then
		self:MERCHANT_SHOW()
	end
end

function core:MERCHANT_SHOW()
	Debug("MERCHANT_SHOW")
	self.at_merchant = true
	self.events:Fire("Merchant_Open")
end

function core:MERCHANT_CLOSED()
	Debug("MERCHANT_CLOSED")
	self.at_merchant = nil
	self.events:Fire("Merchant_Close")
end

function item_value(item, force_vendor)
	local vendor = select(11, GetItemInfo(item)) or 0
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
	table.wipe(drop_slots)
	table.wipe(sell_slots)
	table.wipe(slot_contents)
	table.wipe(slot_counts)
	table.wipe(slot_stacksizes)
	table.wipe(slot_values)
	table.wipe(slot_weightedvalues)
	table.wipe(slot_valuesources)

	local total, total_sell, total_drop = 0, 0, 0

	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local itemid, link, count, stacksize, quality, value, source = GetConsideredItemInfo(bag, slot)
			if itemid then
				local bagslot = encode_bagslot(bag, slot)
				slot_contents[bagslot] = link
				slot_counts[bagslot] = count
				slot_stacksizes[bagslot] = stacksize
				slot_values[bagslot] = value * count
				slot_weightedvalues[bagslot] = db.profile.full_stacks and (value * stacksize) or (value * count)
				slot_valuesources[bagslot] = source
				if db.profile.always_consider[itemid] or quality <= db.profile.threshold then
					total_drop = total_drop + slot_values[bagslot]
					table.insert(drop_slots, bagslot)
				end
				if db.profile.always_consider[itemid] or quality <= db.profile.sell_threshold then
					total_sell = total_sell + slot_values[bagslot]
					table.insert(sell_slots, bagslot)
				end
				total = total + slot_values[bagslot]
			end
		end
	end
	
	table.sort(drop_slots, slot_sorter)
	table.sort(sell_slots, slot_sorter)
	self.events:Fire("Junk_Update", #drop_slots, #sell_slots, total_drop, total_sell, total)
end

-- The rest is utility functions used above:

function GetConsideredItemInfo(bag, slot)
	-- this tells us whether or not the item in this slot could possibly be a candidate for dropping/selling
	local link = GetContainerItemLink(bag, slot)
	if not link then return end -- empty slot!
	
	local _, count, _, quality = GetContainerItemInfo(bag, slot)
	local stacksize = select(8, GetItemInfo(link))
	-- quality_ is -1 if the item requires "special handling"; stackable, quest, whatever.
	-- I'm not actually sure how best to handle this; it's not really a problem with greys, but
	-- whites and above could have quest-item issues. Though I suppose quest items don't have
	-- vendor values, so...
	if quality == -1 then quality = select(3, GetItemInfo(link)) end
	if not quality then return end -- if we don't know the quality now, something weird is going on

	local itemid = link_to_id(link)
	if db.profile.never_consider[itemid] then return end
	if not db.profile.always_consider[itemid] then
		if quality > db.profile.threshold and quality > db.profile.sell_threshold then
			return
		end
	end
	local value, source = item_value(itemid, quality < db.profile.auction_threshold)
	if (not value) or value == 0 then return end
	
	return itemid, link, count, stacksize, quality, value, source
end

function slot_sorter(a,b)
	if slot_weightedvalues[a] == slot_weightedvalues[b] then
		if slot_values[a] == slot_values[b] then
			return slot_counts[a] < slot_counts[b]
		end
		return slot_values[a] < slot_values[b]
	end
	return slot_weightedvalues[a] < slot_weightedvalues[b]
end

function link_to_id(link) return link and tonumber(string.match(link, "item:(%d+)")) end -- "item" because we only care about items, duh
core.link_to_id = link_to_id

function verify_slot_contents(bagslot)
	-- This check won't notice if the itemids and counts are the same, but the item has a
	-- different enchantment / gem situation. Since dropping/selling enchanted / gemmed items
	-- is quite unlikely, I don't care that much about this.
	-- If it turns out to matter, the link-comparison could be updated to check for it.
	Debug("Verifying slot contents", bagslot)
	local bag, slot = decode_bagslot(bagslot)
	if link_to_id(slot_contents[bagslot]) ~= link_to_id(GetContainerItemLink(bag, slot)) then
		Debug("Verification failed, itemids don't match",
			"expected", link_to_id(slot_contents[bagslot]),
			"found", link_to_id(GetContainerItemLink(bag, slot))
		)
		return false
	end
	local _, count = GetContainerItemInfo(bag, slot)
	if slot_counts[bagslot] ~= count then
		Debug("Verification failed, counts don't match",
			"expected", slot_counts[bagslot],
			"found", count
		)
		return false
	end
	Debug("Slot contents are ok")
	return true
end
core.verify_slot_contents = verify_slot_contents

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

function add_junk_to_tooltip(tooltip, slots)
	slots = slots or drop_slots
	if #slots == 0 then
		tooltip:AddLine("Nothing")
		return
	else
		local total = 0
		for _, bagslot in ipairs(slots) do
			tooltip:AddDoubleLine(pretty_bagslot_name(bagslot), copper_to_pretty_money(slot_values[bagslot]) ..
				(slot_values[bagslot] ~= slot_weightedvalues[bagslot] and (' (' .. copper_to_pretty_money(slot_weightedvalues[bagslot]) .. ')') or '') ..
				(db.profile.auction and
					(' '..(slot_valuesources[bagslot] == 'vendor' and '|cff9d9d9d' or '|cff1eff00') ..
					slot_valuesources[bagslot]:sub(1,1)) ..
					(slot_valuesources[bagslot] == 'vendor' and '|r' or '') or ''
				),
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
	Debug("drop_bagslot", bagslot, sell_only and 'sell_only' or '')
	Debug("At merchant?", core.at_merchant and 'yes' or 'no')
	local bag, slot = decode_bagslot(bagslot)
	if CursorHasItem() then
		return DEFAULT_CHAT_FRAME:AddMessage("DropTheCheapestThing Error: Can't delete/sell items while an item is on the cursor. Aborting.", 1, 0, 0)
	end
	if sell_only and not core.at_merchant then
		return DEFAULT_CHAT_FRAME:AddMessage(("DropTheCheapestThing Error: Can't sell items while not at a merchant. Aborting."):format(slot_contents[bagslot], GetContainerItemLink(bag, slot)), 1, 0, 0)
	end
	if not (bagslot and slot_contents[bagslot]) then
		return DEFAULT_CHAT_FRAME:AddMessage("DropTheCheapestThing Error: Nothing found in requested slot. Aborting.", 1, 0, 0)
	end
	if not verify_slot_contents(bagslot) then
		return DEFAULT_CHAT_FRAME:AddMessage(("DropTheCheapestThing Error: Expected %s in bag slot, found %s instead. Aborting."):format(slot_contents[bagslot], GetContainerItemLink(bag, slot) or "nothing"), 1, 0, 0)
	end

	if core.at_merchant then
		DEFAULT_CHAT_FRAME:AddMessage("Selling "..pretty_bagslot_name(bagslot).." for "..copper_to_pretty_money(slot_values[bagslot]))
		UseContainerItem(bag, slot)
	else
		DEFAULT_CHAT_FRAME:AddMessage("Dropping "..pretty_bagslot_name(bagslot).." worth "..copper_to_pretty_money(slot_values[bagslot]))
		PickupContainerItem(bag, slot)
		DeleteCursorItem()
	end
end
core.drop_bagslot = drop_bagslot

