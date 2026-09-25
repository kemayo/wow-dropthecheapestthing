local myname, ns = ...

local core = LibStub("AceAddon-3.0"):GetAddon(myname)
local module = core:NewModule("Config")
local db

local function item_name(info)
	return C_Item.GetItemInfo(info.arg) or 'itemid:'..tostring(info.arg)
end

local function removable_item(itemid)
	local _, itemType, itemSubtype = C_Item.GetItemInfoInstant(itemid)
	return {
		type = "execute",
		name = item_name,
		desc = (itemType and itemSubtype) and ("%s %s"):format(itemType, itemSubtype) or UNKNOWN,
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
			core:BAG_UPDATE_DELAYED()
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
			core:BAG_UPDATE_DELAYED()
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

	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
	profiles.order = 40

	local options = function() return {
		type = "group",
		name = "DropTheCheapestThing",
		get = function(info) return db.profile[info[#info]] end,
		set = function(info, v) db.profile[info[#info]] = v; core:BAG_UPDATE_DELAYED() end,
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
					mark_in_bags = {
						type = "toggle",
						name = "Mark junk in your bags",
						desc = "Show the junk icon on these items in the default bags, Bagnon, and Baganator.",
						order = 60,
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
						set = function(info, v) db.profile.low[info[#info]] = v; core:BAG_UPDATE_DELAYED() end,
						args = {
							food = { name = "Food & drink", type = "toggle", order = 10 },
							potion = { name = "Potions", type = "toggle", order = 20 },
							bandage = { name = "Bandages", type = "toggle", order = 30 },
							scroll = { name = "Scrolls", type = "toggle", order = 40 },
						},
					},
					soulbound = {
						type = "toggle",
						name = "Soulbound items",
						desc = "Things which are soulbound to you are much less likely to be things you want to drop.",
						order = 40,
					},
					valueless = {
						type = "toggle",
						name = "Valueless items",
						desc = "Some items technically have no value. These are more likely than average to be interesting toy or holiday items. Note that this includes your hearthstone...",
						order = 40,
					},
					appearance = {
						type = "toggle",
						name = "Unknown appearances",
						desc = "Consider items whose appearances you don't yet know",
						disabled = function() return not _G.C_TransmogCollection end,
						order = 50,
					},
					appearance_threshold = {
						type = "range",
						name = "Appearance threshold",
						desc = "Only hold on to unknown appearances for items of at least this quality. Poor and common gear became collectable in 10.0.5, so raise this to 1 if you'd rather your greys were still junk.",
						min = 0, max = 7, step = 1,
						disabled = function()
							return db.profile.appearance or not _G.C_TransmogCollection
						end,
						order = 55,
					},
				}
			},
			always = item_list_group("Always Consider", 20, "Items listed here will *always* be considered junk and sold/dropped, regardless of the quality threshold that has been chosen. Be careful with this -- you'll never be prompted about it, and it will have no qualms about dropping things that could be auctioned for 5000g.", db.profile.always_consider),
			never = item_list_group("Never Consider", 30, "Items listed here will *never* be considered junk and sold/dropped, regardless of the quality threshold that has been chosen.", db.profile.never_consider),
			profiles = profiles,
		},
		plugins = self.plugins,
	} end
	self.plugins = {}
	-- self.options = options

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(myname, options)
	self.categoryID = select(2, LibStub("AceConfigDialog-3.0"):AddToBlizOptions(myname, myname))

	db.RegisterCallback(self, "OnProfileChanged", "RefreshProfile")
	db.RegisterCallback(self, "OnProfileCopied", "RefreshProfile")
	db.RegisterCallback(self, "OnProfileReset", "RefreshProfile")
end

function module:RefreshProfile()
	-- the item lists in the options are read out of the profile, and what
	-- counts as junk has just changed under us
	LibStub("AceConfigRegistry-3.0"):NotifyChange(myname)
	core:BAG_UPDATE_DELAYED()
end

function module:ShowConfig()
	Settings.OpenToCategory(self.categoryID)
end

local list_names = { always_consider = "Always Consider", never_consider = "Never Consider" }

BINDING_HEADER_DROPTHECHEAPESTTHING = myname
BINDING_NAME_DROPTHECHEAPESTTHING_TOGGLE_ALWAYS = list_names.always_consider..": toggle hovered item"
BINDING_NAME_DROPTHECHEAPESTTHING_TOGGLE_NEVER = list_names.never_consider..": toggle hovered item"
BINDING_NAME_DROPTHECHEAPESTTHING_DROP = "Drop the cheapest item"
BINDING_NAME_DROPTHECHEAPESTTHING_SELL = "Sell the cheapest item"
BINDING_NAME_DROPTHECHEAPESTTHING_SELL_OR_DROP = "Sell or drop the cheapest item"

-- Bindings.xml calls this:
function core.ToggleConfigListItemFromMouse(key)
	if not GameTooltip:IsVisible() then return end
	local _, link = GameTooltip:GetItem()
	local itemid = link and core.link_to_id(link)
	if not itemid then return end
	if db.profile[key][itemid] then
		db.profile[key][itemid] = nil
		DEFAULT_CHAT_FRAME:AddMessage(myname .. ": removed " .. link .. " from " .. list_names[key])
	else
		db.profile[key][itemid] = true
		DEFAULT_CHAT_FRAME:AddMessage(myname .. ": added " .. link .. " to " .. list_names[key])
	end
	-- If the config window is visible this will rebuild it and remove the item from the lists:
	LibStub("AceConfigRegistry-3.0"):NotifyChange(myname)
	core:BAG_UPDATE_DELAYED()
end

SLASH_DROPTHECHEAPESTTHING1 = "/dropcheap"
SLASH_DROPTHECHEAPESTTHING2 = "/dtct"
function SlashCmdList.DROPTHECHEAPESTTHING(input)
	local command = strtrim(input or ""):lower()
	if command == "drop" then
		core.API.Drop()
	elseif command == "sell" then
		core.API.Sell()
	elseif command == "sell all" then
		core.API.Sell(true, true)
	else
		module:ShowConfig()
	end
end
