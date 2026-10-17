--[[
	Взаимодействие с товарищем: посмотреть на него и нажать E.
	Перевязать (своей аптечкой, 3 с, оба стоят рядом), передать аптечку/магазины, осмотреть, подбодрить.
]]

local IA = {}
SCP.Interact = IA
IA.Range = 95

IA.Actions = {
	{ id = "heal", text = "Перевязать", icon = "medkit", sub = "ВАША АПТЕЧКА · 3 С" },
	{ id = "givemed", text = "Передать аптечку", icon = "heart", sub = "ИЗ СНАРЯЖЕНИЯ" },
	{ id = "giveammo", text = "Передать магазины", icon = "box", sub = "ПАТРОНЫ ВАШЕГО ОРУЖИЯ" },
	{ id = "inspect", text = "Осмотреть", icon = "eye", sub = "СОСТОЯНИЕ" },
	{ id = "cheer", text = "Подбодрить", icon = "hand", sub = "+ ВЫНОСЛИВОСТЬ" },
}

function IA.Target(ply)
	local tr = util.TraceHull({ start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * IA.Range, filter = ply,
		mins = Vector(-6, -6, -6), maxs = Vector(6, 6, 6), mask = MASK_SHOT })
	local e = tr.Entity
	if IsValid(e) and e:IsPlayer() and e:Alive() and e:InGame() then return e end
end
