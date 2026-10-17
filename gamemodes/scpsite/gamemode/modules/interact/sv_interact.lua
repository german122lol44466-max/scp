--[[
	Взаимодействие на сервере.
]]

local IA = SCP.Interact
local I = SCP.Items

local function near(a, b) return IsValid(a) and IsValid(b) and a:GetPos():DistToSqr(b:GetPos()) < (IA.Range + 40) ^ 2 end

local function slotOf(ply, id)
	for s = 1, I.Slots do
		local it = ply.scpInv and ply.scpInv[s]
		if it and it.id == id then return s end
	end
end

local acts = {}

acts.heal = function(ply, t)
	local s = slotOf(ply, "medkit")
	if not s then SCP.Notify(ply, "Нет аптечки.", "warn") return end
	if t:Health() >= t:GetMaxHealth() then SCP.Notify(ply, t:SCPName() .. " не ранен.", "info") return end
	if ply.scpHealing then return end
	ply.scpHealing = true
	ply:SetNW2Float("scp.action", CurTime() + 3)
	ply:SetNW2String("scp.actionText", "Перевязываю: " .. t:SCPName())
	t:SetNW2Float("scp.action", CurTime() + 3)
	t:SetNW2String("scp.actionText", ply:SCPName() .. " перевязывает вас")
	ply:EmitSound("scpsite/fx/bandage.mp3", 60)
	timer.Simple(3, function()
		if not IsValid(ply) then return end
		ply.scpHealing = false
		ply:SetNW2Float("scp.action", 0)
		if IsValid(t) then t:SetNW2Float("scp.action", 0) end
		if not near(ply, t) or not ply:Alive() or not t:Alive() then SCP.Notify(ply, "Перевязка прервана.", "warn") return end
		local s2 = slotOf(ply, "medkit")
		if not s2 then return end
		I.Take(ply, s2, 1)
		t:SetHealth(math.min(t:GetMaxHealth(), t:Health() + 50))
		t:EmitSound("items/medshot4.wav", 60)
		SCP.Stats.Add(ply, "healed", 1)
		SCP.Phrases.SendLine(t, ({ "Спасибо… Жить буду.", "Должен буду.", "Уф. Лучше." })[math.random(3)])
	end)
end

acts.givemed = function(ply, t)
	local s = slotOf(ply, "medkit")
	if not s then SCP.Notify(ply, "Нет аптечки.", "warn") return end
	if not I.Give(t, "medkit", 1) then SCP.Notify(ply, "У " .. t:SCPName() .. " нет места.", "warn") return end
	I.Take(ply, s, 1)
	SCP.Notify(t, ply:SCPName() .. " передал вам аптечку.", "ok")
	SCP.Notify(ply, "Аптечка передана.", "ok")
end

acts.giveammo = function(ply, t)
	local w = ply:GetActiveWeapon()
	local tw = t:GetActiveWeapon()
	if not IsValid(w) or w:GetPrimaryAmmoType() < 0 then return end
	local s = slotOf(ply, "ammo")
	if s then
		if I.Give(t, "ammo", 1) then I.Take(ply, s, 1) SCP.Notify(t, ply:SCPName() .. " передал вам магазины.", "ok") end
		return
	end
	local typ = IsValid(tw) and tw:GetPrimaryAmmoType() or w:GetPrimaryAmmoType()
	local mine = ply:GetAmmoCount(typ)
	local give = math.min(mine, math.max(IsValid(tw) and tw:GetMaxClip1() or 30, 30))
	if give <= 0 then SCP.Notify(ply, "Нечем поделиться — нет подходящих патронов.", "warn") return end
	ply:RemoveAmmo(give, typ)
	t:GiveAmmo(give, typ)
	SCP.Notify(t, ply:SCPName() .. " передал вам " .. give .. " патронов.", "ok")
end

acts.cheer = function(ply, t)
	if (ply.scpCheerAt or 0) > CurTime() then return end
	ply.scpCheerAt = CurTime() + 20
	t:SetNW2Float("scp.stamina", math.min(SCP.Config.Stamina.Max, SCP.Stamina.Get(t) + 35))
	t:SetNW2Bool("scp.exhausted", false)
	SCP.Phrases.SendLine(ply, ({ "Держись. Мы почти выбрались.", "Дыши. Я рядом.", "Ещё немного, брат.", "Соберись. Ты нам нужен." })[math.random(4)])
end

net.Receive("scp.interact.act", function(_, ply)
	local t, id = net.ReadEntity(), net.ReadString()
	if not ply:InGame() or not ply:Alive() or not IsValid(t) or not t:IsPlayer() or t == ply or not t:InGame() or not t:Alive() then return end
	if not near(ply, t) then return end
	if (ply.scpInteractAt or 0) > CurTime() then return end
	ply.scpInteractAt = CurTime() + 0.5
	if acts[id] then acts[id](ply, t) end
end)
