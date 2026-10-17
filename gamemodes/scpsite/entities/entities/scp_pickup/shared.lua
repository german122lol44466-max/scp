ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Предмет"
ENT.Category = "SCP — Объект 19"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "ItemID")
	self:NetworkVar("Int", 0, "Note")
end

function ENT:ItemName()
	local note = self:GetNote()
	return SCP.Items.Name(self:GetItemID(), note > 0 and { note = note } or nil)
end
