--[[
	Менеджер SCP: появление, «бессмертие» и надёжность.
	- SCP нельзя убить (урон гасится) — их можно только вернуть в камеру по сюжету;
	- если NPC пропал (удалён аддоном/очисткой, умер, упал под карту, застрял вне мира) — через
	  def.respawn секунд он появляется снова на своей точке или на точке блуждания вне поля зрения игроков;
	- если долго (45 с) рядом нет игроков — переходит ближе к отряду, на точку, которую никто не видит;
	- NPC-версии получают ненависть к игрокам и цель (ближайший живой боец).
]]

local M = {}
SCP.SCPs = M
M.Active = M.Active or {}   -- [key] = { ent, want, deadAt, lastNear }

local C = SCP.Config
local P = SCP.Points

local function players()
	local out = {}
	for _, p in ipairs(player.GetAll()) do
		if p:InGame() and p:Alive() then out[#out + 1] = p end
	end
	return out
end

local function seenByAnyone(pos)
	for _, p in ipairs(players()) do
		local eye = p:EyePos()
		if eye:DistToSqr(pos) < 2500 * 2500 then
			local tr = util.TraceLine({ start = eye, endpos = pos + Vector(0, 0, 40), filter = p, mask = MASK_VISIBLE })
			if not tr.Hit then return true end
		end
	end
	return false
end

-- Куда поставить: своя точка; если её видят или она слишком далеко — точка блуждания рядом с отрядом, вне поля зрения
local function pickSpot(def, preferNear)
	local own = P.First(def.point)
	local roam = P.Get("scp_roam")
	local plys = players()
	if preferNear and #roam > 0 and #plys > 0 then
		local best, bestD
		for _, r in ipairs(roam) do
			local d = math.huge
			for _, p in ipairs(plys) do d = math.min(d, r.pos:Distance(p:GetPos())) end
			if d > 700 and d < 2600 and not seenByAnyone(r.pos) and (not bestD or d < bestD) then best, bestD = r, d end
		end
		if best then return best end
	end
	if own and not seenByAnyone(own.pos) then return own end
	for _, r in RandomPairs(roam) do
		if not seenByAnyone(r.pos) then return r end
	end
	return own or roam[1]
end

local function hateAll(ent)
	if not ent:IsNPC() then return end
	for _, p in ipairs(player.GetAll()) do
		ent:AddEntityRelationship(p, p:InGame() and D_HT or D_NU, 99)
	end
	local near, nd
	for _, p in ipairs(players()) do
		local d = p:GetPos():DistToSqr(ent:GetPos())
		if not nd or d < nd then near, nd = p, d end
	end
	if near and (not IsValid(ent:GetEnemy()) or not ent:GetEnemy():Alive()) then
		ent:SetEnemy(near)
		ent:UpdateEnemyMemory(near, near:GetPos())
	end
end

local function create(key, spot)
	local def = C.SCPs[key]
	if not spot then return end
	local ent = ents.Create(def.class)
	if not IsValid(ent) then
		print("[SCP] Не удалось создать " .. def.class .. " — установите аддон с " .. def.name .. " на сервер и клиентам.")
		return
	end
	ent:SetPos(spot.pos + Vector(0, 0, 4))
	ent:SetAngles(Angle(0, spot.ang.y, 0))
	ent:Spawn()
	ent:Activate()
	ent.scpKey = key
	ent.scpManaged = true
	ent:SetNW2String("scp.key", key)
	hateAll(ent)
	return ent
end

function M.Spawn(key)
	local def = C.SCPs[key]
	if not def then return end
	local a = M.Active[key]
	if a and IsValid(a.ent) then a.want = true return a.ent end
	local ent = create(key, pickSpot(def, false))
	M.Active[key] = { ent = ent, want = true, deadAt = not IsValid(ent) and CurTime() or nil, lastNear = CurTime() }
	return ent
end

function M.Get(key)
	local a = M.Active[key]
	return a and IsValid(a.ent) and a.ent or nil
end

function M.Contain(key)
	local a = M.Active[key]
	if not a then return end
	a.want = false
	if IsValid(a.ent) then
		local e = a.ent
		e.scpRemoving = true
		local fx = EffectData()
		fx:SetOrigin(e:WorldSpaceCenter())
		util.Effect("cball_explode", fx)
		e:Remove()
	end
	M.Active[key] = nil
end

function M.ClearAll()
	for key in pairs(M.Active) do M.Contain(key) end
	M.Active = {}
end

-- Бессмертие
hook.Add("EntityTakeDamage", "scp.scps.immortal", function(ent, dmg)
	if ent.scpManaged then
		dmg:SetDamage(0)
		dmg:ScaleDamage(0)
		return true
	end
end)

-- Удалили не мы — вернётся
hook.Add("EntityRemoved", "scp.scps", function(ent)
	if not ent.scpManaged or ent.scpRemoving then return end
	local a = M.Active[ent.scpKey]
	if a and a.ent == ent and a.want then a.deadAt = CurTime() end
end)

timer.Create("scp.scps.watch", 2, 0, function()
	for key, a in pairs(M.Active) do
		local def = C.SCPs[key]
		if a.want then
			local ent = a.ent
			if IsValid(ent) and ent:IsNPC() and ent:Health() <= 0 then
				ent.scpRemoving = true
				ent:Remove()
				ent = nil
				a.deadAt = a.deadAt or CurTime()
			end
			if not IsValid(ent) then
				a.deadAt = a.deadAt or CurTime()
				if CurTime() - a.deadAt >= (def.respawn or 20) then
					a.ent = create(key, pickSpot(def, true))
					a.deadAt = IsValid(a.ent) and nil or CurTime()
					a.lastNear = CurTime()
				end
			else
				-- под картой или вне мира
				if not util.IsInWorld(ent:GetPos()) or ent:GetPos().z < -16000 then
					local spot = pickSpot(def, true)
					if spot then ent:SetPos(spot.pos + Vector(0, 0, 4)) end
				end
				-- никого рядом — переходит ближе
				local near = false
				for _, p in ipairs(players()) do
					if p:GetPos():DistToSqr(ent:GetPos()) < 2200 * 2200 then near = true break end
				end
				if near then a.lastNear = CurTime()
				elseif CurTime() - (a.lastNear or 0) > 45 and not seenByAnyone(ent:GetPos()) then
					local spot = pickSpot(def, true)
					if spot then
						ent:SetPos(spot.pos + Vector(0, 0, 4))
						a.lastNear = CurTime()
					end
				end
				if ent:IsNPC() and ent:Health() < 1000 then ent:SetHealth(100000) end
				hateAll(ent)
			end
		end
	end
end)

-- Новые игроки на задании — тоже враги для NPC
hook.Add("PlayerSpawn", "scp.scps", function(ply)
	timer.Simple(0.5, function()
		if not IsValid(ply) then return end
		for _, a in pairs(M.Active) do
			if IsValid(a.ent) and a.ent:IsNPC() then a.ent:AddEntityRelationship(ply, ply:InGame() and D_HT or D_NU, 99) end
		end
	end)
end)

-- Какой SCP по классу (для причины смерти, статистики)
function M.KeyOf(ent)
	if not IsValid(ent) then return nil end
	if ent.scpKey then return ent.scpKey end
	local cls = ent:GetClass()
	for key, def in pairs(C.SCPs) do if def.class == cls then return key end end
end
