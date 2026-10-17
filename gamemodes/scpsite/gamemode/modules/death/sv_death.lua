--[[
	Смерть на задании: запоминаем причину, считаем статистику. Воскрешает сюжет (между этапами).
]]

local function causeOf(ply, attacker, inflictor)
	if IsValid(attacker) then
		if attacker == ply then return "Несчастный случай" end
		if attacker:IsPlayer() then return "Огонь своих · " .. attacker:SCPName() end
		local cls = attacker:GetClass()
		if cls == SCP.Config.Enemy096 then return "SCP-096" end
		if attacker:IsNPC() then return "Враждебный объект" end
	end
	return "Неизвестно"
end

hook.Add("PlayerDeath", "scp.death", function(ply, inflictor, attacker)
	if not ply:InGame() then return end
	ply:SetNW2Bool("scp.dead", true)
	ply:SetNW2String("scp.cause", causeOf(ply, attacker, inflictor))
	ply:SetNW2Float("scp.diedAt", CurTime())
	ply:SetNW2Bool("scp.radio", false)
	SCP.Stats.Add(ply, "deaths", 1)
	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= ply then SCP.Stats.Add(attacker, "teamkills", 1) end
	if IsValid(attacker) and attacker:GetClass() == SCP.Config.Enemy096 then SCP.Stats.Add(ply, "killed_by_096", 1) end
	hook.Run("SCP.PlayerDied", ply, attacker)
end)

hook.Add("OnNPCKilled", "scp.death", function(npc, attacker)
	if IsValid(attacker) and attacker:IsPlayer() then SCP.Stats.Add(attacker, "kills", 1) end
end)

-- Наблюдение: камера у живых товарищей — их окрестности должны быть в PVS погибшего
hook.Add("SetupPlayerVisibility", "scp.death.spec", function(ply)
	if ply:Alive() or not ply:InGame() then return end
	for _, p in ipairs(player.GetAll()) do
		if p ~= ply and p:Alive() and p:InGame() then AddOriginToPVS(p:GetPos() + Vector(0, 0, 60)) end
	end
end)
