local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")

if Bagnon then
    local UpdateBorder = Bagnon.Item.UpdateBorder
    local r, g, b = GetItemQualityColor(0)

    function Bagnon.Item:UpdateBorder(...)
        -- First, do the core bagnon behavior for stuff like new-item flashing
        UpdateBorder(self, ...)
        self.JunkIcon:Hide()

        -- Now override if we have junk
        local info = self:GetInfo()
        if info and info.id then
            local bag, slot = self:GetBag(), self:GetID()
            if not (type(bag) == "number") then
                return
            end
            local bagslot = core.encode_bagslot(bag, slot)
            if core.slot_contents[bagslot] then
                self.IconGlow:SetVertexColor(r, g, b, 0.5)
                self.IconGlow:SetShown(r)
                self.JunkIcon:Show()
            end
        end
    end

    core.RegisterCallback("Bagnon", "Junk_Update", function()
        Bagnon.Frames:Update()
    end)
end