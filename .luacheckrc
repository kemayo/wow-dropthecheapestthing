std = "lua51"
max_line_length = false
exclude_files = {
    "libs/",
    ".luacheckrc"
}

ignore = {
    "211", -- Unused local variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "311", -- Value assigned to a local variable is unused
    "542", -- empty if branch
}

globals = {
    "SLASH_DROPTHECHEAPESTTHING1",
    "SLASH_DROPTHECHEAPESTTHING2",

    "SlashCmdList",
    "StaticPopupDialogs",
    "UpdateContainerFrameAnchors",

    "Bagnon",
}

read_globals = {
    "bit",
    "ceil", "floor",
    "mod",
    "max",
    "table", "tinsert", "wipe", "copy",
    "string", "tostringall", "strtrim", "strmatch",

    -- our own globals

    -- misc custom, third party libraries
    "LibStub", "tekDebug",
    "GetAuctionBuyout",

    -- API functions
    "BankButtonIDToInvSlotID",
    "ContainerIDToInventoryID",
    "ReagentBankButtonIDToInvSlotID",
    "CursorHasItem",
    "DeleteCursorItem",
    "GetAuctionItemSubClasses",
    "GetBuildInfo",
    "GetBackpackAutosortDisabled",
    "GetBagSlotFlag",
    "GetBankAutosortDisabled",
    "GetBankBagSlotFlag",
    "GetContainerNumFreeSlots",
    "GetContainerNumSlots",
    "GetContainerItemID",
    "GetContainerItemInfo",
    "GetContainerItemLink",
    "GetCurrentGuildBankTab",
    "GetCursorInfo",
    "GetGuildBankItemInfo",
    "GetGuildBankItemLink",
    "GetGuildBankTabInfo",
    "GetGuildBankNumSlots",
    "GetInventoryItemLink",
    "GetItemClassInfo",
    "GetItemFamily",
    "GetItemInfo",
    "GetItemInfoInstant",
    "GetItemQualityColor",
    "GetTime",
    "InCombatLockdown",
    "IsAltKeyDown",
    "IsControlKeyDown",
    "IsShiftKeyDown",
    "IsReagentBankUnlocked",
    "PickupContainerItem",
    "PickupGuildBankItem",
    "QueryGuildBankTab",
    "SplitContainerItem",
    "SplitGuildBankItem",
    "UnitIsAFK",
    "UnitLevel",
    "UnitName",
    "UseContainerItem",

    -- FrameXML frames
    "BankFrame",
    "MerchantFrame",
    "GameTooltip",
    "UIParent",
    "WorldFrame",
    "DEFAULT_CHAT_FRAME",
    "GameFontHighlightSmall",

    -- FrameXML API
    "CreateFrame",
    "InterfaceOptionsFrame_OpenToCategory",
    "ToggleDropDownMenu",
    "UIDropDownMenu_AddButton",
    "UISpecialFrames",
    "ScrollingEdit_OnCursorChanged",
    "ScrollingEdit_OnUpdate",

    -- FrameXML Constants
    "BACKPACK_CONTAINER",
    "BACKPACK_TOOLTIP",
    "BAG_CLEANUP_BAGS",
    "BAG_FILTER_ICONS",
    "BAGSLOT",
    "BANK",
    "BANK_BAG_PURCHASE",
    "BANK_CONTAINER",
    "CONFIRM_BUY_BANK_SLOT",
    "DEFAULT",
    "EQUIP_CONTAINER",
    "ITEM_BIND_QUEST",
    "ITEM_BNETACCOUNTBOUND",
    "ITEM_CONJURED",
    "ITEM_SOULBOUND",
    "LE_BAG_FILTER_FLAG_EQUIPMENT",
    "LE_BAG_FILTER_FLAG_IGNORE_CLEANUP",
    "LE_ITEM_CLASS_WEAPON",
    "LE_ITEM_CLASS_ARMOR",
    "LE_ITEM_CLASS_CONTAINER",
    "LE_ITEM_CLASS_GEM",
    "LE_ITEM_CLASS_ITEM_ENHANCEMENT",
    "LE_ITEM_CLASS_CONSUMABLE",
    "LE_ITEM_CLASS_GLYPH",
    "LE_ITEM_CLASS_TRADEGOODS",
    "LE_ITEM_CLASS_RECIPE",
    "LE_ITEM_CLASS_BATTLEPET",
    "LE_ITEM_CLASS_QUESTITEM",
    "LE_ITEM_CLASS_MISCELLANEOUS",
    "LE_ITEM_QUALITY_POOR",
    "MAX_CONTAINER_ITEMS",
    "NEW_ITEM_ATLAS_BY_QUALITY",
    "NO",
    "NUM_BAG_SLOTS",
    "NUM_BANKBAGSLOTS",
    "NUM_CONTAINER_FRAMES",
    "NUM_LE_BAG_FILTER_FLAGS",
    "RAID_CLASS_COLORS",
    "REAGENT_BANK",
    "REAGENTBANK_CONTAINER",
    "REAGENTBANK_DEPOSIT",
    "REMOVE",
    "SOUNDKIT",
    "STATICPOPUP_NUMDIALOGS",
    "TEXTURE_ITEM_QUEST_BANG",
    "TEXTURE_ITEM_QUEST_BORDER",
    "UIDROPDOWNMENU_MENU_VALUE",
    "YES",
}
