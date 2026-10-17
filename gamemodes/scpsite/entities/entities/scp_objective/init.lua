AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	if self:GetModel() == "" then self:SetModel("models/props_lab/reciever_cart.mdl") end
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
	if self:GetDuration() <= 0 then self:SetDuration(6) end
end

local function looking(ply, ent)
	if ply:EyePos():DistToSqr(ent:WorldSpaceCenter()) > 130 * 130 then return false end
	local tr = ply:GetEyeTrace()
	return tr.Entity == ent or (tr.HitPos:DistToSqr(ent:WorldSpaceCenter()) < 50 * 50)
end

function ENT:Think()
	if self:GetDone() then return end
	local users = 0
	for _, p in ipairs(player.GetAll()) do
		if p:InGame() and p:Alive() and p:KeyDown(IN_USE) and looking(p, self) then
			users = users + 1
			self.LastUser = p
		end
	end
	local dt = FrameTime()
	local prog = self:GetProgress()
	if users > 0 then
		-- вдвоём быстрее
		prog = prog + dt / self:GetDuration() * (1 + (users - 1) * 0.5)
		if not self.Loop then
			self.Loop = CreateSound(self, "scpsite/fx/terminal_loop.wav")
			self.Loop:PlayEx(0.5, 100)
		end
	else
		prog = math.max(0, prog - dt * 0.15)
		if self.Loop then self.Loop:Stop() self.Loop = nil end
	end
	if prog >= 1 then
		prog = 1
		self:SetDone(true)
		if self.Loop then self.Loop:Stop() self.Loop = nil end
		self:EmitSound("scpsite/fx/terminal_done.mp3", 70)
		if self.OnDone then self:OnDone(self.LastUser) end
	end
	self:SetProgress(prog)
	self:NextThink(CurTime())
	return true
end

function ENT:OnRemove()
	if self.Loop then self.Loop:Stop() end
end
