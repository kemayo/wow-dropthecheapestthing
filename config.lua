local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")
local module = core:NewModule("Config")
local db

local function removable_item(itemid)
	local itemname = GetItemInfo(itemid)
	return {
		type = "execute",
		name = itemname or 'itemid:'..tostring(itemid),
		desc = not itemname and "Item isn't cached" or nil,
		arg = itemid,
	}
end

local function item_list_group(name, order, description, db_table)
	local group = {
		type = "group",
		name = name,
		order = order,
		args = {},
	}
	group.args.about = {
		type = "description",
		name = description,
		order = 0,
	}
	group.args.add = {
		type = "input",
		name = "Add",
		desc = "Add an item, either by pasting the item link, dragging the item into the field, or entering the itemid.",
		get = function(info) return '' end,
		set = function(info, v)
			local itemid = core.link_to_id(v) or tonumber(v)
			db_table[itemid] = true
			group.args.remove.args[tostring(itemid)] = removable_item(itemid)
			core:BAG_UPDATE()
		end,
		validate = function(info, v)
			if v:match("^%d+$") or v:match("item:%d+") then
				return true
			end
		end,
		order = 10,
	}
	group.args.remove = {
		type = "group",
		inline = true,
		name = "Remove",
		order = 20,
		func = function(info)
			db_table[info.arg] = nil
			group.args.remove.args[info[#info]] = nil
			core:BAG_UPDATE()
		end,
		args = {
			about = {
				type = "description",
				name = "Remove an item.",
				order = 0,
			},
		},
	}
	for itemid in pairs(db_table) do
		group.args.remove.args[tostring(itemid)] = removable_item(itemid)
	end
	return group
end

function module:OnInitialize()
	db = core.db

	local options = function() return {
		type = "group",
		name = "DropTheCheapestThing",
		get = function(info) return db.profile[info[#info]] end,
		set = function(info, v) db.profile[info[#info]] = v; core:BAG_UPDATE() end,
		args = {
			general = {
				type = "group",
				name = "General",
				order = 10,
				args = {
					auction = {
						type = "group",
						name = "Auction values",
						inline = true,
						order = 20,
						args = {
							auction = {
								type = "toggle",
								name = "Auction values",
								desc = "If a supported auction addon is installed, use the higher of the vendor and buyout prices as the item's value.",
								order = 10,
							},
							auction_threshold = {
								type = "range",
								name = "Auction threshold",
								desc = "Only consider auction values for items of at least this quality.",
								min = 0, max = 7, step = 1,
								order = 20,
							},
						},
					},
					full_stacks = {
						type = "toggle",
						name = "Use full stack value",
						order = 30,
					},
				},
				plugins = {},
			},
			what = {
				type = "group",
				name = "What to drop",
				order = 15,
				args = {
					threshold = {
						type = "range",
						name = "Quality Threshold (Drop)",
						desc = "Choose the maximum quality of item that will be considered for dropping. 0 is grey, 1 is white, 2 is green, etc.",
						min = 0, max = 7, step = 1,
						order = 10,
					},
					sell_threshold = {
						type = "range",
						name = "Quality Threshold (Sell)",
						desc = "Choose the maximum quality of item that will be considered for selling. 0 is grey, 1 is white, 2 is green, etc.",
						min = 0, max = 7, step = 1,
						order = 15,
					},
					low = {
						type = "group",
						name = "Low level items",
						desc = "Which items of a lower level (more than 10 below yours) to automatically count as junk",
						inline = true,
						order = 20,
						get = function(info) return db.profile.low[info[#info]] end,
						set = function(info, v) db.profile.low[info[#info]] = v; core:BAG_UPDATE() end,
						args = {
							food = { name = "Food & drink", type = "toggle", order = 10 },
							potion = { name = "Potions", type = "toggle", order = 20 },
							bandage = { name = "Bandages", type = "toggle", order = 30 },
							scroll = { name = "Scrolls", type = "toggle", order = 40 },
						},
					},
				}
			},
			always = item_list_group("Always Consider", 20, "Items listed here will *always* be considered junk and sold/dropped, regardless of the quality threshold that has been chosen. Be careful with this -- you'll never be prompted about it, and it will have no qualms about dropping things that could be auctioned for 5000g.", db.profile.always_consider),
			never = item_list_group("Never Consider", 30, "Items listed here will *never* be considered junk and sold/dropped, regardless of the quality threshold that has been chosen.", db.profile.never_consider),
		},
		plugins = self.plugins,
	} end
	self.plugins = {}
	-- self.options = options

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("DropTheCheapestThing", options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DropTheCheapestThing", "DropTheCheapestThing")
end

function module:ShowConfig()
	LibStub("AceConfigDialog-3.0"):Open("DropTheCheapestThing")
end

SLASH_DROPTHECHEAPESTTHING1 = "/dropcheap"
SLASH_DROPTHECHEAPESTTHING2 = "/dtct"
function SlashCmdList.DROPTHECHEAPESTTHING()
	module:ShowConfig()
end
