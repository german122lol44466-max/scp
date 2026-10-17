--[[
	Лобби: создание, приглашения, выход, старт задания.
	Одиночная игра — лобби из одного игрока, которое сразу стартует (остальных кикает, если scp_solo_kick 1).
]]

local L = SCP.Lobby
L.List = L.List or {}
local nextId = 1

local soloKick = GetConVar("scp_solo_kick")

local function members(lobby)
	local out = {}
	for _, p in ipairs(lobby.members) do if IsValid(p) then out[#out + 1] = p end end
	lobby.members = out
	return out
end

function L.Get(ply)
	return L.List[ply:SCPLobby()]
end

function L.Sync(lobby)
	local list = members(lobby)
	local ch = SCP.Story.ChapterDef(lobby.chapter or 1)
	for _, p in ipairs(list) do
		if not p:InGame() then p:SetNW2String("scp.faction", ch.faction) end
	end
	for _, p in ipairs(list) do
		net.Start("scp.lobby.sync")
		net.WriteUInt(lobby.id, 16)
		net.WriteEntity(lobby.leader)
		net.WriteBool(lobby.started)
		net.WriteUInt(lobby.chapter or 1, 4)
		net.WriteUInt(#list, 5)
		for _, m in ipairs(list) do net.WriteEntity(m) end
		net.Send(p)
	end
end

local function sendNone(ply)
	net.Start("scp.lobby.sync")
	net.WriteUInt(0, 16)
	net.Send(ply)
end

function L.Create(ply)
	if L.Get(ply) then return L.Get(ply) end
	local lobby = { id = nextId, leader = ply, members = { ply }, started = false, chapter = math.Clamp(SCP.Data.Get(ply, "chapter", 1), 1, #SCP.Story.Chapters) }
	nextId = nextId + 1
	L.List[lobby.id] = lobby
	ply:SetNW2Int("scp.lobby", lobby.id)
	ply:SetNW2String("scp.state", "lobby")
	L.Sync(lobby)
	return lobby
end

-- quiet — без перевода игрока в меню (используется при входе в редактор и отключении)
function L.Leave(ply, quiet)
	local lobby = L.Get(ply)
	ply:SetNW2Int("scp.lobby", 0)
	if not lobby then return end
	table.RemoveByValue(lobby.members, ply)
	local rest = members(lobby)
	if #rest == 0 then
		L.List[lobby.id] = nil
	else
		if lobby.leader == ply then
			lobby.leader = rest[1]
			SCP.Notify(rest[1], "Вы теперь лидер отряда.", "info")
		end
		L.Sync(lobby)
	end
	if not quiet and IsValid(ply) then sendNone(ply) end
end

function L.Join(ply, lobby)
	if #members(lobby) >= SCP.Config.LobbyMax then
		SCP.Notify(ply, "Отряд уже полный.", "warn")
		return
	end
	L.Leave(ply, true)
	lobby.members[#lobby.members + 1] = ply
	ply:SetNW2Int("scp.lobby", lobby.id)
	ply:SetNW2String("scp.state", "lobby")
	L.Sync(lobby)
	for _, p in ipairs(lobby.members) do
		if p ~= ply then SCP.Notify(p, ply:SCPName() .. " присоединился к отряду.", "ok") end
	end
	-- отряд уже на задании — сразу туда же
	if lobby.started then L.Deploy({ ply }, lobby.chapter) end
end

-- Отправить игроков на задание (затемнение -> спавн на точках).
function L.Deploy(plys, chapter)
	SCP.Fade(plys, 0.8, 0.6, 1.2)
	timer.Simple(0.85, function()
		for _, p in ipairs(plys) do
			if IsValid(p) then
				p:SetNW2String("scp.faction", SCP.Story.ChapterDef(chapter).faction)
				p:SetNW2String("scp.state", "playing")
				p.scpJoinedAt = CurTime()
				p:Spawn()
			end
		end
		SCP.Story.OnDeploy(plys, chapter)
	end)
end

-- Можно ли начать главу: нужен спавн фракции; идёт другая глава — ждём
function L.CanStart(ply, lobby)
	local ch = SCP.Story.ChapterDef(lobby.chapter)
	if SCP.Points.Count(ch.spawn) == 0 and SCP.Points.Count("spawn") == 0 then
		SCP.Notify(ply, "На карте нет точек спавна отряда. Админ: scp_edit → «Спавн отряда».", "error")
		return false
	end
	local st = SCP.Story.State
	if st.running and st.chapter ~= lobby.chapter then
		SCP.Notify(ply, "Сейчас идёт глава " .. SCP.Story.ChapterDef(st.chapter).roman .. ". Выберите её, чтобы присоединиться, или дождитесь конца.", "warn")
		return false
	end
	return true
end

function L.Start(lobby)
	lobby.started = true
	L.Sync(lobby)
	L.Deploy(members(lobby), lobby.chapter)
end

-- ------------------------------------------------------------------ сеть --
net.Receive("scp.menu.multi", function(_, ply)
	if ply:SCPState() ~= "menu" or SCP.InEdit(ply) then return end
	L.Create(ply)
end)

net.Receive("scp.menu.solo", function(_, ply)
	local chapter = net.ReadUInt(4)
	if ply:SCPState() ~= "menu" or SCP.InEdit(ply) then return end
	if soloKick:GetBool() then
		for _, p in ipairs(player.GetAll()) do
			if p ~= ply and not p:IsBot() and not p:IsListenServerHost() then
				p:Kick("Сервер переведён в одиночную игру (" .. ply:Nick() .. ")")
			elseif p ~= ply and p:IsBot() then
				p:Kick("solo")
			end
		end
	end
	-- одиночная игра забирает сервер: идущее задание прерывается
	if soloKick:GetBool() and SCP.Story.State.running then SCP.Story.Abort() end
	local lobby = L.Create(ply)
	lobby.solo = true
	if SCP.Story.Chapters[chapter] then lobby.chapter = chapter SCP.Data.Set(ply, "chapter", chapter) end
	L.Sync(lobby)
	if not L.CanStart(ply, lobby) then return end
	L.Start(lobby)
end)

net.Receive("scp.menu.back", function(_, ply)
	if ply:SCPState() == "lobby" then
		L.Leave(ply)
		ply:SetNW2String("scp.state", "menu")
	end
end)

net.Receive("scp.lobby.leave", function(_, ply)
	if ply:SCPState() ~= "lobby" then return end
	L.Leave(ply)
	ply:SetNW2String("scp.state", "menu")
end)

net.Receive("scp.lobby.model", function(_, ply)
	local i = net.ReadUInt(4)
	if ply:InGame() then return end
	local fid, fac = L.FactionOf(ply)
	if i >= 1 and i <= #fac.models then
		ply:SetNW2Int("scp.model." .. fid, i)
		local models = SCP.Data.Get(ply, "models", {})
		models[fid] = i
		SCP.Data.Set(ply, "models", models)
	end
end)

net.Receive("scp.lobby.chapter", function(_, ply)
	local i = net.ReadUInt(4)
	local lobby = L.Get(ply)
	if not lobby or lobby.leader ~= ply or lobby.started or not SCP.Story.Chapters[i] then return end
	lobby.chapter = i
	SCP.Data.Set(ply, "chapter", i)
	L.Sync(lobby)
end)

net.Receive("scp.lobby.name", function(_, ply)
	local name = SCP.CleanName(net.ReadString())
	if ply:InGame() then return end
	if utf8.len(name) and utf8.len(name) < 2 then
		SCP.Notify(ply, "Имя слишком короткое.", "warn")
		return
	end
	ply:SetNW2String("scp.name", name)
	SCP.Data.Set(ply, "name", name)
end)

net.Receive("scp.lobby.invite", function(_, ply)
	local target = net.ReadEntity()
	local lobby = L.Get(ply)
	if not lobby or not IsValid(target) or not target:IsPlayer() or target == ply then return end
	if (ply.scpInviteAt or 0) > CurTime() then return end
	ply.scpInviteAt = CurTime() + 1.5
	if target:InGame() then SCP.Notify(ply, target:SCPName() .. " сейчас на задании.", "warn") return end
	if target:SCPLobby() == lobby.id then return end
	target.scpInvites = target.scpInvites or {}
	target.scpInvites[lobby.id] = CurTime() + 60
	net.Start("scp.lobby.invited")
	net.WriteUInt(lobby.id, 16)
	net.WriteEntity(ply)
	net.Send(target)
	SCP.Notify(ply, "Приглашение отправлено: " .. target:SCPName(), "ok")
end)

net.Receive("scp.lobby.answer", function(_, ply)
	local id, accept = net.ReadUInt(16), net.ReadBool()
	local exp = ply.scpInvites and ply.scpInvites[id]
	if not exp then return end
	ply.scpInvites[id] = nil
	local lobby = L.List[id]
	if not lobby or exp < CurTime() then
		SCP.Notify(ply, "Приглашение устарело.", "warn")
		return
	end
	if not accept then
		SCP.Notify(lobby.leader, ply:SCPName() .. " отклонил приглашение.", "info")
		return
	end
	if ply:InGame() then return end
	L.Join(ply, lobby)
end)

net.Receive("scp.lobby.kick", function(_, ply)
	local target = net.ReadEntity()
	local lobby = L.Get(ply)
	if not lobby or lobby.leader ~= ply or not IsValid(target) or target == ply then return end
	if target:SCPLobby() ~= lobby.id or target:InGame() then return end
	L.Leave(target)
	target:SetNW2String("scp.state", "menu")
	SCP.Notify(target, "Вас исключили из отряда.", "warn")
end)

net.Receive("scp.lobby.start", function(_, ply)
	local lobby = L.Get(ply)
	if not lobby or lobby.leader ~= ply or lobby.started then return end
	if not L.CanStart(ply, lobby) then return end
	L.Start(lobby)
end)

hook.Add("PlayerDisconnected", "scp.lobby", function(ply) L.Leave(ply, true) end)
