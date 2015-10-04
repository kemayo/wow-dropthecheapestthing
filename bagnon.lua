local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")

if Bagnon then
    local ItemSlot = Bagnon.ItemSlot
    local UpdateBorder = ItemSlot.UpdateBorder
    local r, g, b = GetItemQualityColor(0)

    function ItemSlot:UpdateBorder(...)
        -- First, do the core bagnon behavior for stuff like new-item flashing
        UpdateBorder(self, ...)

        -- Now override if we have junk
        local link = self:GetItem()
        if link then
            local id = tonumber(strmatch(link, 'item:(%d+)'))
            local bag, slot = self:GetBag(), self:GetID()
            if not (type(bag) == "number") then
                return
            end
            local bagslot = core.encode_bagslot(bag, slot)
            if core.slot_contents[bagslot] then
                self:SetBorderColor(r, g, b)
            end
        end
    end

    core.RegisterCallback("Button", "Junk_Update", function()
        for _,frame in pairs(Bagnon.frames) do
            if frame.itemFrame then
                -- bagnon creates these on first use
                frame.itemFrame:ForAll('UpdateBorder')
            end
        end
    end)
end