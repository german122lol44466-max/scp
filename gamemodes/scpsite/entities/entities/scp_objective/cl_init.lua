include("shared.lua")

local glow = Material("sprites/light_glow02_add")

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	if self:GetDone() then return end
	local a = 0.5 + 0.5 * math.sin(RealTime() * 4)
	render.SetMaterial(glow)
	render.DrawSprite(self:WorldSpaceCenter() + Vector(0, 0, 10), 40, 40, Color(230, 180, 60, 120 * a))
end

ENT.SCPPrompt = function(self)
	if self:GetDone() then return nil end
	return "Удерживайте — " .. self:GetLabel(), self:GetProgress()
end
