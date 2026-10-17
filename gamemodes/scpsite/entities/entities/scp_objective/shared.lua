ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Цель задания"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

-- Удерживайте E, глядя на объект: прогресс общий для всех, кто держит.
function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Label")
	self:NetworkVar("Float", 0, "Progress")
	self:NetworkVar("Float", 1, "Duration")
	self:NetworkVar("Bool", 0, "Done")
	self:NetworkVar("Bool", 1, "Blocked")
end
