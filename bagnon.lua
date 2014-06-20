local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")

if Bagnon then
    local ItemSlot = Bagnon.ItemSlot
    local SetBorderQuality = ItemSlot.SetBorderQuality
    local r, g, b = GetItemQualityColor(0)

    function ItemSlot:SetBorderQuality(...)
        local link
        if self.GetItemSlotInfo then
            link = select(7, self:GetItemSlotInfo())
        else
            link = select(7, self:GetInfo())
        end

        if link then
            local id = tonumber(strmatch(link, 'item:(%d+)'))
            local bag, slot = self:GetBag(), self:GetID()
            local bagslot = core.encode_bagslot(bag, slot)
            
            if core.slot_contents[bagslot] then
                self.questBorder:Hide()
                self.border:SetVertexColor(r, g, b, self:GetHighlightAlpha())
                self.border:Show()
                return
            end
        end
        
        SetBorderQuality(self, ...)
    end

    core.RegisterCallback("Button", "Junk_Update", function()
        for _,frame in pairs(Bagnon.frames) do
            if frame.itemFrame then
                -- bagnon creates these on first use
                frame.itemFrame:UpdateEverything()
            end
        end
    end)
end