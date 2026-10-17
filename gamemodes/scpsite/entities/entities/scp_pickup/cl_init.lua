include("shared.lua")

-- Мягкое мерцание, чтобы предмет было видно в полутьме
local glow = Material("sprites/light_glow02_add")

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	local d = self:GetPos():Distance(EyePos())
	if d > 500 then return end
	local a = (1 - d / 500) * (0.5 + 0.5 * math.sin(RealTime() * 3 + self:EntIndex()))
	local col = self:GetItemID() == "keycard" and Color(255, 200, 80) or Color(220, 230, 255)
	render.SetMaterial(glow)
	render.DrawSprite(self:WorldSpaceCenter(), 18, 18, Color(col.r, col.g, col.b, 90 * a))
end

ENT.SCPPrompt = function(self) return "Подобрать: " .. self:ItemName() end
