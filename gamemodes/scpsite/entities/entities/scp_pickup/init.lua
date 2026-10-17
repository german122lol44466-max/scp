AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:SetItem(id, data)
	self:SetItemID(id)
	if data and data.note then self:SetNote(data.note) end
	local def = SCP.Items.Defs[id]
	self:SetModel(def and def.model or "models/props_junk/cardboard_box004a.mdl")
	if def and def.color then self:SetColor(def.color) end
end

function ENT:Initialize()
	if self:GetModel() == "" then self:SetItem(self:GetItemID() ~= "" and self:GetItemID() or "medkit") end
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:SetUseType(SIMPLE_USE)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end
end

function ENT:Use(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:InGame() or not ply:Alive() then return end
	local id = self:GetItemID()
	local data = self:GetNote() > 0 and { note = self:GetNote() } or nil
	if not SCP.Items.Give(ply, id, 1, data) then
		SCP.Notify(ply, "Нет места в снаряжении.", "warn")
		return
	end
	ply:EmitSound("scpsite/fx/pickup.mp3", 60)
	SCP.Notify(ply, "Подобрано: " .. self:ItemName(), "ok")
	if id == "note" then SCP.Stats.Add(ply, "notes", 1) end
	hook.Run("SCP.PickedUp", ply, id, self)
	self:Remove()
end
