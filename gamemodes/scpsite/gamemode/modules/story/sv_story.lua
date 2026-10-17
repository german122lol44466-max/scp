--[[
	Сюжет на сервере: главы и этапы, цели, SCP, затемнение, диалоги, катсцены, воскрешение
	погибших между этапами, таймеры, финал. Одна глава идёт на сервере одновременно:
	отряды, вышедшие позже на ту же главу, присоединяются к заданию.
]]

local S = SCP.Story
local P = SCP.Points
local I = SCP.Items

S.Ents = S.Ents or {}

local function playing(aliveOnly)
	local out = {}
	for _, p in ipairs(player.GetAll()) do
		if p:InGame() and (not aliveOnly or p:Alive()) then out[#out + 1] = p end
	end
	return out
end
S.Playing = playing

function S.Broadcast(target)
	net.Start("scp.story.state")
	net.WriteBool(S.State.running)
	net.WriteUInt(S.State.chapter or 1, 4)
	net.WriteUInt(S.State.stage, 6)
	net.WriteFloat(S.State.started)
	net.WriteUInt(S.State.collected or 0, 6)
	net.WriteFloat(S.State.progress or 0)
	net.WriteFloat(S.State.deadline or 0)
	local pos = S.State.goalPos
	net.WriteBool(pos ~= nil)
	if pos then net.WriteVector(pos) end
	if target then net.Send(target) else net.Broadcast() end
end

-- Оповещение громкой связи всем на задании (звук + субтитры)
function S.Say(id, delay)
	timer.Simple(delay or 0, function()
		if not S.State.running and id ~= "fail" and id ~= "exit_done" and id ~= "c5_end" then return end
		net.Start("scp.story.say")
		net.WriteString(id)
		net.Send(playing())
	end)
end

-- Диалог: { "player"|"command"|"self", текст }; говорящий-игрок выбирается из живых
function S.Talk(lines, delay)
	local t = delay or 0
	for _, l in ipairs(lines or {}) do
		local who, text = l[1], l[2]
		timer.Simple(t, function()
			if not S.State.running then return end
			local speaker = NULL
			if who == "player" then
				local alive = playing(true)
				if #alive == 0 then return end
				speaker = alive[math.random(#alive)]
			end
			SCP.Dialog.Send(playing(), who, speaker, text)
		end)
		t = t + math.max(3.5, utf8.len(text) / 13)
	end
	return t
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

-- Место появления: на старте — точки отряда фракции, позже — рядом с живым товарищем
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
	local ch = S.ChapterDef()
	local list = P.Get(ch.spawn)
	if #list == 0 then list = P.Get("spawn") end
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

-- ----------------------------------------------------------------- этапы --
local function startStage(i)
	clearEnts(false)
	S.State.stage = i
	S.State.collected = 0
	S.State.progress = 0
	S.State.goalPos = nil
	local st = S.Current()
	S.State.deadline = st.timer and (CurTime() + st.timer) or 0

	for _, p in ipairs(playing()) do
		if not p:Alive() then p:Spawn() end
	end

	if st.startFX then S.FX(st.startFX) end
	for k, id in ipairs(st.startVO or {}) do S.Say(id, 1 + (k - 1) * 10) end
	S.Talk(st.talk, (#(st.startVO or {}) > 0) and (#st.startVO * 10 + 1) or 2)

	if st.kind == "reach" or st.kind == "survive" then
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
			local stage = i
			e.OnDone = function(_, user) S.Complete(stage, user) end
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
	for k, key in ipairs(st.spawn or {}) do
		timer.Simple(3 + (k - 1) * 2, function()
			if S.State.running and S.State.stage == i then SCP.SCPs.Spawn(key) end
		end)
	end
	S.Broadcast()
	hook.Run("SCP.StageStarted", i, st)
end

function S.Complete(i, who)
	if not S.State.running or S.State.stage ~= i or S.Completing then return end
	S.Completing = true
	local st = S.Current()
	if st.doneFX then S.FX(st.doneFX) end
	for _, key in ipairs(st.contain or {}) do SCP.SCPs.Contain(key) end
	local delay = 0
	for k, id in ipairs(st.doneVO or {}) do S.Say(id, (k - 1) * 9) delay = delay + 9 end
	if IsValid(who) then SCP.Phrases.Say(who, "done") end
	hook.Run("SCP.StageDone", i, st, who)
	local stages = S.StagesOf()
	timer.Simple(math.max(4, delay * 0.8), function()
		S.Completing = false
		if not S.State.running or S.State.stage ~= i then return end
		if i >= #stages then
			local outro = S.ChapterDef().outro
			if outro then
				SCP.Cutscene.Play(playing(), outro, function() S.Finish(true) end)
			else
				S.Finish(true)
			end
		else
			startStage(i + 1)
		end
	end)
end

function S.Begin(chapter)
	clearEnts(true)
	SCP.SCPs.ClearAll()
	S.State = { running = true, chapter = chapter or 1, stage = 0, started = CurTime() }
	S.Completing = false
	S.FX("reset")
	for _, p in ipairs(playing()) do I.Reset(p) end
	spawnWorldItems()
	S.Broadcast()
	local ch = S.ChapterDef()
	local function go()
		if S.State.running and S.State.stage == 0 then startStage(1) end
	end
	if ch.intro and P.Count("cs_" .. ch.intro) >= 2 then
		timer.Simple(1.5, function() SCP.Cutscene.Play(playing(), ch.intro, go) end)
	else
		timer.Simple(3, go)
	end
end

function S.OnDeploy(plys, chapter)
	if not S.State.running then
		S.Begin(chapter)
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
	local chapter = S.State.chapter
	S.State.running = false
	SCP.SCPs.ClearAll()
	local plys = playing()
	for _, p in ipairs(plys) do
		SCP.Stats.Add(p, win and "missions" or "missions_failed", 1)
		if win then
			local done = SCP.Data.Get(p, "chapters_done", {})
			done[chapter] = true
			SCP.Data.Set(p, "chapters_done", done)
			p:SetNW2Int("scp.done." .. chapter, 1)
		end
	end
	if not win then S.Say("fail") end
	net.Start("scp.story.end")
	net.WriteBool(win)
	net.WriteFloat(time)
	net.WriteUInt(S.State.stage, 6)
	net.WriteUInt(chapter, 4)
	net.Send(plys)
	timer.Simple(12, function()
		clearEnts(true)
		S.State = { running = false, chapter = chapter, stage = 0, started = 0 }
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
	SCP.SCPs.ClearAll()
	S.State = { running = false, chapter = S.State.chapter, stage = 0, started = 0 }
	engine.LightStyle(0, "m")
	S.Broadcast()
	for _, lobby in pairs(SCP.Lobby.List) do lobby.started = false end
end

-- Выйти с задания самому (ESC → «Покинуть задание»)
net.Receive("scp.story.leave", function(_, ply)
	if not ply:InGame() then return end
	I.Reset(ply)
	local lobby = SCP.Lobby.Get(ply)
	SCP.Fade(ply, 0.5, 0.3, 0.7)
	timer.Simple(0.5, function()
		if not IsValid(ply) then return end
		ply:SetNW2String("scp.state", lobby and "lobby" or "menu")
		if lobby then SCP.Lobby.Sync(lobby) end
		if ply:Alive() then ply:KillSilent() end
		ply:Spawn()
	end)
end)

-- --------------------------------------------------------- проверки целей --
timer.Create("scp.story.tick", 0.25, 0, function()
	if not S.State.running or S.InCutscene then return end
	local all, alive = playing(), playing(true)
	if #all == 0 then S.Abort() return end
	if #alive == 0 then S.Finish(false) return end

	local st = S.Current()
	if not st then return end
	if (S.State.deadline or 0) > 0 and CurTime() > S.State.deadline and not S.Completing then
		S.Finish(false)
		return
	end
	if st.kind == "reach" and S.State.goalPos then
		local r = st.radius or 150
		for _, p in ipairs(alive) do
			if p:GetPos():DistToSqr(S.State.goalPos) <= r * r then S.Complete(S.State.stage, p) break end
		end
	elseif st.kind == "survive" and S.State.goalPos then
		local r = st.radius or 250
		local inside = false
		for _, p in ipairs(alive) do
			if p:GetPos():DistToSqr(S.State.goalPos) <= r * r then inside = true break end
		end
		local was = S.State.progress or 0
		if inside then S.State.progress = math.min(1, was + 0.25 / st.duration) end
		if math.floor(was * 40) ~= math.floor(S.State.progress * 40) then S.Broadcast() end
		if S.State.progress >= 1 then S.Complete(S.State.stage) end
	elseif st.kind == "collect" then
		local n = 0
		for _, p in ipairs(all) do n = n + I.Count(p, st.item) end
		if n ~= (S.State.collected or 0) then
			S.State.collected = n
			S.Broadcast()
		end
		if n >= st.count then S.Complete(S.State.stage) end
	elseif st.kind == "use" and IsValid(S.Objective) then
		if st.needItem then
			local have = false
			for _, p in ipairs(all) do if I.Count(p, st.needItem) > 0 then have = true break end end
			S.Objective:SetBlocked(not have)
			if not have then S.Objective:SetProgress(0) end
		end
		if st.useVO and S.Objective:GetProgress() > 0.05 and not S.Objective.vo then
			S.Objective.vo = true
			S.Say(st.useVO)
		end
	end
end)

-- Напоминание про 096, пока он на свободе
timer.Create("scp.story.reminder", 80, 0, function()
	if S.State.running and SCP.SCPs.Get("096") and math.random() < 0.6 then S.Say("reminder") end
end)

-- Обычная жизнь объекта: плановые объявления, пока всё спокойно (до нарушения)
timer.Create("scp.story.routine", 70, 0, function()
	if not S.State.running or SCP.SCPs.Get("096") or SCP.SCPs.Get("173") or SCP.SCPs.Get("049") then return end
	if math.random() < 0.55 then S.Say(S.Routine[math.random(#S.Routine)]) end
end)

hook.Add("PlayerInitialSpawn", "scp.story", function(ply)
	timer.Simple(2, function() if IsValid(ply) then S.Broadcast(ply) end end)
end)

concommand.Add("scp_story_skip", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if S.State.running then S.Complete(S.State.stage, ply) end
end)

concommand.Add("scp_story_stop", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if S.State.running then S.Finish(false) end
end)
