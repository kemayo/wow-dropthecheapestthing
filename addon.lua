local myname, ns = ...

ns.CLASSIC = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE

local core = LibStub("AceAddon-3.0"):NewAddon("DropTheCheapestThing", "AceEvent-3.0", "AceBucket-3.0")

local debugf = tekDebug and tekDebug:GetFrame("DropTheCheapestThing")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end
core.Debug = Debug

local db, iterate_bags, slot_sorter, copper_to_pretty_money, encode_bagslot,
	decode_bagslot, pretty_bagslot_name, drop_bagslot, add_junk_to_tooltip,
	link_to_id, item_value, GetConsideredItemInfo, verify_slot_contents,
	GetAppearanceAndSource, CanLearnAppearance, HasAppearance

-- compat:
local PickupContainerItem = _G.PickupContainerItem or C_Container.PickupContainerItem
local UseContainerItem = _G.UseContainerItem or C_Container.UseContainerItem
local GetContainerNumSlots = _G.GetContainerNumSlots or C_Container.GetContainerNumSlots
local GetContainerItemLink = _G.GetContainerItemLink or C_Container.GetContainerItemLink
local GetContainerItemInfo = _G.GetContainerItemInfo or function(...)
	local info = C_Container.GetContainerItemInfo(...)
	if info then
		return info.iconFileID, info.stackCount, info.isLocked, info.quality, info.isReadable, info.hasLoot, info.hyperlink, info.isFiltered, info.hasNoValue, info.itemID, info.isBound
	end
end

local LE_ITEM_CLASS_CONSUMABLE_POTION = 1
local LE_ITEM_CLASS_CONSUMABLE_ELIXIR = 2
local LE_ITEM_CLASS_CONSUMABLE_FLASK = 3
local LE_ITEM_CLASS_CONSUMABLE_FOOD = 5
local LE_ITEM_CLASS_CONSUMABLE_BANDAGE = 7
local LE_ITEM_CLASS_CONSUMABLE_OTHER = 8

local drop_slots = {}
local sell_slots = {}
local slot_contents = {}
local slot_counts = {}
local slot_stacksizes = {}
local slot_values = {}
local slot_weightedvalues = {}
local slot_valuesources = {}
local slot_soulbound = setmetatable({}, {__index = function(self, bagslot)
	local bag, slot = decode_bagslot(bagslot)
	local is_soulbound = C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(bag, slot))
	self[bagslot] = is_soulbound
	return is_soulbound
end,})
local item_quest = setmetatable({}, {__index = function(self, itemid)
	local bindType = select(14, GetItemInfo(itemid))
	local is_quest = bindType == LE_ITEM_BIND_QUEST
	if bindType ~= nil then -- just in case
		self[itemid] = is_quest
	end
	return is_quest
end,})

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
			valueless = false,
			soulbound = false,
			appearance = false, -- consider unknown appearances?
			low = {
				food = false,
				scroll = false,
				potion = false,
				bandage = false,
			}
		},
	}, DEFAULT)
	self.db = db
	self:RegisterBucketEvent("BAG_UPDATE_DELAYED", 1)
	self:RegisterBucketEvent("GET_ITEM_INFO_RECEIVED", 1)
	self:RegisterEvent("MERCHANT_SHOW")
	self:RegisterEvent("MERCHANT_CLOSED")
end

function core:OnEnable()
	self:BAG_UPDATE_DELAYED()
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

-- returns: price, source, vendorable
function item_value(link, force_vendor)
	local vendor = select(11, GetItemInfo(link)) or 0
	if db.profile.auction and GetAuctionBuyout and not force_vendor then
		local auction = GetAuctionBuyout(link) or 0
		if auction > vendor then
			return auction, 'auction', vendor > 0
		end
	end
	return vendor, 'vendor', vendor > 0
end
core.item_value = item_value

local player_level
function core:BAG_UPDATE_DELAYED()
	table.wipe(drop_slots)
	table.wipe(sell_slots)
	table.wipe(slot_contents)
	table.wipe(slot_counts)
	table.wipe(slot_stacksizes)
	table.wipe(slot_values)
	table.wipe(slot_weightedvalues)
	table.wipe(slot_valuesources)
	table.wipe(slot_soulbound)

	local total, total_sell, total_drop = 0, 0, 0
	player_level = UnitLevel('player')

	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local itemid, link, count, stacksize, quality, value, source, forced, sellable = GetConsideredItemInfo(bag, slot)
			if itemid then
				local bagslot = encode_bagslot(bag, slot)
				slot_contents[bagslot] = link
				slot_counts[bagslot] = count
				slot_stacksizes[bagslot] = stacksize
				slot_values[bagslot] = value * count
				slot_weightedvalues[bagslot] = db.profile.full_stacks and (value * stacksize) or (value * count)
				slot_valuesources[bagslot] = source
				if forced or quality <= db.profile.threshold then
					total_drop = total_drop + slot_values[bagslot]
					table.insert(drop_slots, bagslot)
				end
				if (forced or quality <= db.profile.sell_threshold) and sellable then
					total_sell = total_sell + slot_values[bagslot]
					table.insert(sell_slots, bagslot)
				end
				total = total + slot_values[bagslot]
			end
		end
	end

	table.sort(drop_slots, slot_sorter)
	table.sort(sell_slots, slot_sorter)
	Debug("Junk updated", #drop_slots, #sell_slots, total_drop, total_sell, total)
	self.events:Fire("Junk_Update", #drop_slots, #sell_slots, total_drop, total_sell, total)
end
core.GET_ITEM_INFO_RECEIVED = core.BAG_UPDATE_DELAYED

-- The rest is utility functions used above:

-- hardcoded things
local never_consider = {
	[40110] = true, -- Haunted Memento
	[183616] = true, -- Accursed Keepsake
}
local filters = {
	-- Never consider
	function(bag, slot, itemid)
		if db.profile.never_consider[itemid] or never_consider[itemid] then
			return false
		end
	end,
	-- Always consider
	function(bag, slot, itemid)
		if db.profile.always_consider[itemid] then
			return true
		end
	end,
	-- Low level consumables
	function(bag, slot, itemid, quality, level, class, subclass)
		if class ~= LE_ITEM_CLASS_CONSUMABLE or level == 0 or (player_level - level) <= 10 then
			return
		end
		if slot_soulbound[encode_bagslot(bag, slot)] then
			-- ignore consumables if they're soulbound, regardless of the soulbinding setting
			-- (mostly because of things like Oralius' Whispering Crystal, which is a bound blue reusable "consumable")
			return
		end
		if subclass == LE_ITEM_CLASS_CONSUMABLE_FOOD and db.profile.low.food then
			return true
		end
		if (subclass == LE_ITEM_CLASS_CONSUMABLE_POTION or subclass == LE_ITEM_CLASS_CONSUMABLE_ELIXIR or subclass == LE_ITEM_CLASS_CONSUMABLE_FLASK) and db.profile.low.potion then
			return true
		end
		if subclass == LE_ITEM_CLASS_CONSUMABLE_BANDAGE and db.profile.low.bandage then
			return true
		end
		-- Scrolls are lumped into "Other" now...
		if subclass == LE_ITEM_CLASS_CONSUMABLE_OTHER and db.profile.low.scroll then
			return true
		end
	end,
	-- Quality
	function(bag, slot, itemid, quality, level, class)
		if quality > db.profile.threshold and quality > db.profile.sell_threshold then
			return false
		end
	end,
	-- Bound?
	function(bag, slot, itemid, quality)
		if db.profile.soulbound or quality == 0 then
			-- don't care!
			return
		end
		if slot_soulbound[encode_bagslot(bag, slot)] then
			return false
		end
	end,
	-- Appearance known?
	function(bag, slot)
		if db.profile.appearance or not _G.C_TransmogCollection then
			return
		end
		local link = GetContainerItemLink(bag, slot)
		if link then
			-- print(link, GetAppearanceAndSource(link), HasAppearance(link))
			if GetAppearanceAndSource(link) and not HasAppearance(link) then
				return false
			end
		end
	end,
}

function GetConsideredItemInfo(bag, slot)
	-- this tells us whether or not the item in this slot could possibly be a candidate for dropping/selling
	local link = GetContainerItemLink(bag, slot)
	if not link then return end -- empty slot!

	-- name, link, quality, ilvl, required level, classstring, subclassstring, stacksize, equipslot, texture, value, class, subclass
	local _, _, quality, ilvl, reqLevel, _, _, stacksize, _, _, _, class, subclass = GetItemInfo(link)
	if not quality then return end -- if we don't know the quality now, something weird is going on

	local itemid = link_to_id(link)

	-- We outright shouldn't be trying to drop quest items
	if item_quest[itemid] then
		return
	end

	local action
	for _, filter in ipairs(filters) do
		action = filter(bag, slot, itemid, quality, max(ilvl, reqLevel), class, subclass)
		if action == false then
			return
		end
		if action == true then
			break
		end
	end

	local value, source, sellable = item_value(link, quality < db.profile.auction_threshold)
	if (not value) or value == 0 then
		if db.profile.valueless or action then
			-- forced things should _always_ go through, otherwise it depends on the valueless setting
			value = 0
		else
			return
		end
	end

	local _, count = GetContainerItemInfo(bag, slot)
	return itemid, link, count, stacksize, quality, value, source, action, sellable
end

do
	local brokenItems = {
		-- itemid : {appearanceid, sourceid}
		[153268] = {25124, 90807}, -- Enclave Aspirant's Axe
		[153316] = {25123, 90885}, -- Praetor's Ornamental Edge
	}
	function GetAppearanceAndSource(itemLinkOrID)
		local itemID = GetItemInfoInstant(itemLinkOrID)
		if not itemID then return end
		local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLinkOrID)
		if not appearanceID then
			-- sometimes the link won't actually give us an appearance, but itemID will
			-- e.g. mythic Drape of Iron Sutures from Shadowmoon Burial Grounds
			appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID)
		end
		if not appearanceID and brokenItems[itemID] then
			-- ...and there's a few that just need to be hardcoded
			appearanceID, sourceID = unpack(brokenItems[itemID])
		end
		return appearanceID, sourceID
	end
	local canLearnCache = {}
	function CanLearnAppearance(itemLinkOrID)
		if not _G.C_Transmog then return false end
		local itemID = GetItemInfoInstant(itemLinkOrID)
		if not itemID then return end
		if canLearnCache[itemID] ~= nil then
			return canLearnCache[itemID]
		end
		-- First, is this a valid source at all?
		local canBeChanged, noChangeReason, canBeSource, noSourceReason = C_Transmog.CanTransmogItem(itemID)
		if canBeSource == nil or noSourceReason == 'NO_ITEM' then
			-- data loading, don't cache this
			return
		end
		if not canBeSource then
			canLearnCache[itemID] = false
			return false
		end
		local appearanceID, sourceID = GetAppearanceAndSource(itemLinkOrID)
		if not appearanceID then
			canLearnCache[itemID] = false
			return false
		end
		local hasData, canCollect = C_TransmogCollection.PlayerCanCollectSource(sourceID)
		if hasData then
			canLearnCache[itemID] = canCollect
		end
		return canLearnCache[itemID]
	end
	local hasAppearanceCache = {}
	function HasAppearance(itemLinkOrID)
		local itemID = GetItemInfoInstant(itemLinkOrID)
		if not itemID then return end
		if hasAppearanceCache[itemID] ~= nil then
			-- only use the cache if we need the more expensive checks below...
			return hasAppearanceCache[itemID]
		end
		if C_TransmogCollection.PlayerHasTransmogByItemInfo(itemLinkOrID) then
			-- short-circuit further checks because this specific item is known
			hasAppearanceCache[itemID] = true
			return true
		end
		--[[
		-- Although this isn't known, its appearance might be known from another item
		local appearanceID = GetAppearanceAndSource(itemLinkOrID)
		if not appearanceID then
			hasAppearanceCache[itemID] = false
			return
		end
		local sources = C_TransmogCollection.GetAllAppearanceSources(appearanceID)
		if not sources then return end
		for _, sourceID in ipairs(sources) do
			if C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID) then
				hasAppearanceCache[itemID] = true
				return true
			end
		end
		--]]
		return false
	end
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

-- "item" because we only care about items, duh
function link_to_id(link) return link and tonumber(string.match(link, "item:(%d+)")) end
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
	local max = select(8, GetItemInfo(link)) or 1
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
		-- value might be the auction value, so force-check it
		local value = slot_counts[bagslot] * item_value(slot_contents[bagslot], true)
		DEFAULT_CHAT_FRAME:AddMessage("Selling "..pretty_bagslot_name(bagslot).." for "..copper_to_pretty_money(value))
		UseContainerItem(bag, slot)
	else
		DEFAULT_CHAT_FRAME:AddMessage("Dropping "..pretty_bagslot_name(bagslot).." worth "..copper_to_pretty_money(slot_values[bagslot]))
		PickupContainerItem(bag, slot)
		DeleteCursorItem()
	end
	return slot_values[bagslot] or 0
end
core.drop_bagslot = drop_bagslot
