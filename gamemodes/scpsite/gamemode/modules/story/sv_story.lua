--[[
	Сюжет на сервере: этапы, цели, SCP-096, затемнение, воскрешение погибших между этапами, финал.
	Сюжет один на сервер: отряды, вышедшие позже, присоединяются к идущему заданию.
]]

local S = SCP.Story
local P = SCP.Points
local I = SCP.Items
local C = SCP.Config

S.Ents = S.Ents or {}

local function playing(aliveOnly)
	local out = {}
	for _, p in ipairs(player.GetAll()) do
		if p:InGame() and (not aliveOnly or p:Alive()) then out[#out + 1] = p end
	end
	return out
end

function S.Broadcast(target)
	net.Start("scp.story.state")
	net.WriteBool(S.State.running)
	net.WriteUInt(S.State.stage, 6)
	net.WriteFloat(S.State.started)
	net.WriteUInt(S.State.collected or 0, 6)
	local pos = S.State.goalPos
	net.WriteBool(pos ~= nil)
	if pos then net.WriteVector(pos) end
	if target then net.Send(target) else net.Broadcast() end
end

-- Реплика оповещения: всем на задании (со звуком и субтитрами)
function S.Say(id, delay)
	timer.Simple(delay or 0, function()
		if not S.State.running and id ~= "fail" and id ~= "exit_done" then return end
		net.Start("scp.story.say")
		net.WriteString(id)
		net.Send(playing())
	end)
end

function S.FX(kind)
	net.Start("scp.story.fx")
	net.WriteString(kind)
	net.Send(playing())
	if kind == "blackout" then
		engine.LightStyle(0, "c")
	elseif kind == "power" or kind == "reset" then
		engine.LightStyle(0, "m")
	end
end

local function track(e) S.Ents[#S.Ents + 1] = e return e end

local function clearEnts(all)
	for i = #S.Ents, 1, -1 do
		local e = S.Ents[i]
		if not IsValid(e) then table.remove(S.Ents, i)
		elseif all or e.scpStageEnt then e:Remove() table.remove(S.Ents, i) end
	end
end

-- Место появления: на старте — точки отряда по очереди, позже — рядом с живым товарищем
local spawnIndex = 0
function S.SpawnPoint(ply)
	if S.State.running and S.State.stage > 1 then
		for _, mate in ipairs(playing(true)) do
			if mate ~= ply then
				for _, off in ipairs({ Vector(40, 0, 0), Vector(-40, 0, 0), Vector(0, 40, 0), Vector(0, -40, 0) }) do
					local pos = mate:GetPos() + off
					local tr = util.TraceHull({ start = pos + Vector(0, 0, 8), endpos = pos + Vector(0, 0, 8), mins = Vector(-16, -16, 0), maxs = Vector(16, 16, 72), mask = MASK_PLAYERSOLID })
					if not tr.Hit then return { pos = pos, ang = Angle(0, mate:EyeAngles().y, 0) } end
				end
			end
		end
	end
	local list = P.Get("spawn")
	if #list == 0 then return nil end
	spawnIndex = spawnIndex % #list + 1
	return list[spawnIndex]
end

-- ------------------------------------------------------------ предметы --
local function spawnItem(id, point, data)
	local e = ents.Create("scp_pickup")
	if not IsValid(e) then return end
	e:SetItem(id, data)
	e:SetPos(point.pos + Vector(0, 0, 8))
	e:SetAngles(point.ang)
	e:Spawn()
	return track(e)
end

local function spawnWorldItems()
	for i, p in ipairs(P.Get("note")) do
		spawnItem("note", p, { note = (i - 1) % #SCP.Notes + 1 })
	end
	for _, p in ipairs(P.Get("medkit")) do spawnItem("medkit", p) end
	for _, p in ipairs(P.Get("ammo")) do spawnItem("ammo", p) end
end

-- ------------------------------------------------------------------ 096 --
function S.Spawn096()
	local p = P.First("npc_096")
	if not p then return end
	if not scripted_ents.GetStored(C.Enemy096) and not list.Get("NPC")[C.Enemy096] then
		print("[SCP] Не найден NPC " .. C.Enemy096 .. " — установите аддон с SCP-096 на сервер.")
	end
	local npc = ents.Create(C.Enemy096)
	if not IsValid(npc) then return end
	npc:SetPos(p.pos)
	npc:SetAngles(p.ang)
	npc:Spawn()
	npc:Activate()
	S.NPC096 = track(npc)
end

-- --------------------------------------------------------------- этапы --
local function startStage(i)
	clearEnts(false)
	S.State.stage = i
	S.State.collected = 0
	S.State.goalPos = nil
	local st = S.Stages[i]

	-- погибшие возвращаются в строй
	for _, p in ipairs(playing()) do
		if not p:Alive() then p:Spawn() end
	end

	if st.startFX then S.FX(st.startFX) end
	for k, id in ipairs(st.startVO or {}) do S.Say(id, 1 + (k - 1) * 9) end

	if st.kind == "reach" then
		local p = P.First(st.point)
		S.State.goalPos = p and p.pos
	elseif st.kind == "use" then
		local p = P.First(st.point)
		if p then
			local e = ents.Create("scp_objective")
			e:SetModel(st.model or "models/props_lab/reciever_cart.mdl")
			e:SetPos(p.pos)
			e:SetAngles(p.ang)
			e:SetLabel(st.label)
			e:SetDuration(st.duration or 8)
			e:Spawn()
			e.scpStageEnt = true
			e.OnDone = function(_, user) S.Complete(i, user) end
			track(e)
			S.State.goalPos = p.pos + Vector(0, 0, 40)
			S.Objective = e
		end
	elseif st.kind == "collect" then
		local pts = table.Copy(P.Get(st.spawnPoint))
		for k = #pts, 2, -1 do local j = math.random(k) pts[k], pts[j] = pts[j], pts[k] end
		for k = 1, math.min(st.count, #pts) do
			local e = spawnItem(st.item, pts[k])
			if IsValid(e) then e.scpStageEnt = true end
		end
	end
	if st.spawn096 then timer.Simple(4, S.Spawn096) end
	S.Broadcast()
	hook.Run("SCP.StageStarted", i, st)
end

function S.Complete(i, who)
	if not S.State.running or S.State.stage ~= i or S.Completing then return end
	S.Completing = true
	local st = S.Stages[i]
	if st.doneFX then S.FX(st.doneFX) end
	if st.doneFX == "contain" and IsValid(S.NPC096) then
		S.NPC096:Remove()
		S.NPC096 = nil
	end
	local delay = 0
	for k, id in ipairs(st.doneVO or {}) do S.Say(id, (k - 1) * 8) delay = delay + 8 end
	if IsValid(who) then SCP.Phrases.Say(who, "done") end
	hook.Run("SCP.StageDone", i, st, who)
	timer.Simple(math.max(4, delay * 0.8), function()
		S.Completing = false
		if not S.State.running or S.State.stage ~= i then return end
		if i >= #S.Stages then S.Finish(true) else startStage(i + 1) end
	end)
end

function S.Begin()
	clearEnts(true)
	S.State = { running = true, stage = 0, started = CurTime() }
	S.Completing = false
	S.FX("reset")
	for _, p in ipairs(playing()) do I.Reset(p) end
	spawnWorldItems()
	S.Broadcast()
	timer.Simple(3, function() if S.State.running and S.State.stage == 0 then startStage(1) end end)
end

function S.OnDeploy(plys)
	if not S.State.running then
		S.Begin()
	else
		for _, p in ipairs(plys) do
			if IsValid(p) then I.Reset(p) S.Broadcast(p) end
		end
	end
end

-- Конец задания: экран итогов, через 12 с — обратно в лобби
function S.Finish(win)
	if not S.State.running then return end
	local time = CurTime() - S.State.started
	S.State.running = false
	local plys = playing()
	for _, p in ipairs(plys) do
		SCP.Stats.Add(p, win and "missions" or "missions_failed", 1)
	end
	if not win then S.Say("fail") end
	net.Start("scp.story.end")
	net.WriteBool(win)
	net.WriteFloat(time)
	net.WriteUInt(S.State.stage, 6)
	net.Send(plys)
	timer.Simple(12, function()
		clearEnts(true)
		S.State = { running = false, stage = 0, started = 0 }
		S.FX("reset")
		engine.LightStyle(0, "m")
		for _, p in ipairs(plys) do
			if IsValid(p) and p:InGame() then
				local lobby = SCP.Lobby.Get(p)
				if lobby then lobby.started = false SCP.Lobby.Sync(lobby) end
				I.Reset(p)
				SCP.Fade(p, 0.6, 0.3, 0.8)
				p:SetNW2String("scp.state", lobby and "lobby" or "menu")
				p:KillSilent()
				p:Spawn()
			end
		end
		S.Broadcast()
	end)
end

function S.Abort()
	if not S.State.running then return end
	clearEnts(true)
	S.State = { running = false, stage = 0, started = 0 }
	engine.LightStyle(0, "m")
	S.Broadcast()
	for _, lobby in pairs(SCP.Lobby.List) do lobby.started = false end
end

-- --------------------------------------------------------- проверки целей --
timer.Create("scp.story.tick", 0.25, 0, function()
	if not S.State.running then return end
	local all, alive = playing(), playing(true)
	if #all == 0 then S.Abort() return end
	if #alive == 0 then S.Finish(false) return end

	local st = S.Current()
	if not st then return end
	if st.kind == "reach" and S.State.goalPos then
		local r = st.radius or 150
		for _, p in ipairs(alive) do
			if p:GetPos():DistToSqr(S.State.goalPos) <= r * r then S.Complete(S.State.stage, p) break end
		end
	elseif st.kind == "collect" then
		local n = 0
		for _, p in ipairs(all) do n = n + I.Count(p, st.item) end
		if n ~= (S.State.collected or 0) then
			S.State.collected = n
			S.Broadcast()
		end
		if n >= st.count then S.Complete(S.State.stage) end
	elseif st.kind == "use" and IsValid(S.Objective) then
		-- пульт не работает без нужного предмета у кого-то из отряда
		if st.needItem then
			local have = false
			for _, p in ipairs(all) do if I.Count(p, st.needItem) > 0 then have = true break end end
			if not have then S.Objective:SetProgress(0) end
		end
		if st.useVO and S.Objective:GetProgress() > 0.05 and not S.Objective.vo then
			S.Objective.vo = true
			S.Say(st.useVO)
		end
	end
end)

-- напоминание про 096, пока он на свободе
timer.Create("scp.story.reminder", 75, 0, function()
	if S.State.running and IsValid(S.NPC096) and math.random() < 0.6 then S.Say("reminder") end
end)

hook.Add("PlayerInitialSpawn", "scp.story", function(ply)
	timer.Simple(2, function() if IsValid(ply) then S.Broadcast(ply) end end)
end)

-- Кто-то вышел в меню/отключился — ничего, тик сам решит (никого нет — сброс)
concommand.Add("scp_story_skip", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if S.State.running then S.Complete(S.State.stage, ply) end
end)

concommand.Add("scp_story_stop", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if S.State.running then S.Finish(false) end
end)
