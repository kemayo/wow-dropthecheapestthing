local myname, ns = ...

-- This file is recreating the GetAuctionBuyout API that has mostly faded away
-- since the 8.3 auction-addons crash.
-- https://warcraft.wiki.gg/wiki/GetAuctionBuyout

local origGetAuctionBuyout = GetAuctionBuyout
function GetAuctionBuyout(item)
	-- returns an int, or nil if no providers were available
	local isLink = type(item) == "string"
	local value
	if TSM_API and isLink then
		local tsm_item = TSM_API.ToItemString(item)
		value = (TSM_API.GetCustomPriceValue("DBRecent", tsm_item)) or (TSM_API.GetCustomPriceValue("DBMarket", tsm_item))
	end
	if value then return value end

	if (Auctionator and Auctionator.API and Auctionator.API.v1) then
		if isLink then
			value = Auctionator.API.v1.GetAuctionPriceByItemLink("GetAuctionBuyout", item)
		else
			value = Auctionator.API.v1.GetAuctionPriceByItemID("GetAuctionBuyout", item)
		end
	end
	if value then return value end

	if RECrystallize_PriceCheck and isLink then
		value = RECrystallize_PriceCheck(item)
	end
	if value then return value end

	if RECrystallize_PriceCheckItemID and not isLink then
		value = RECrystallize_PriceCheckItemID(item)
	end
	if value then return value end

	if origGetAuctionBuyout then
		value = origGetAuctionBuyout(item)
	end
	return value
end
