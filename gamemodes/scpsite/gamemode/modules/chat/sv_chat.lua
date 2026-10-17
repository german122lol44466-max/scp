--[[
	Чат на сервере: кому отправить сообщение.
]]

local CH = SCP.Chat
local C = SCP.Config

local function inRange(a, b, r) return a:GetPos():DistToSqr(b:GetPos()) <= r * r end

local function recipients(ply, kind)
	local out = {}
	local st = ply:SCPState()
	for _, p in ipairs(player.GetAll()) do
		local ok = false
		if kind == "ooc" then ok = true
		elseif kind == "dead" then ok = p:InGame() and not p:Alive()
		elseif kind == "lobby" then ok = p:SCPLobby() == ply:SCPLobby() and p:SCPState() == "lobby"
		elseif st == "menu" or st == "edit" then ok = p:SCPState() == st
		elseif kind == "radio" then ok = p:InGame()
		elseif kind == "whisper" then ok = p:InGame() and inRange(p, ply, C.WhisperRange)
		elseif kind == "yell" then ok = p:InGame() and inRange(p, ply, C.YellRange)
		else ok = p:InGame() and (inRange(p, ply, C.ChatRange) or not p:Alive()) end
		if ok then out[#out + 1] = p end
	end
	return out
end

function CH.Send(ply, kind, text)
	local list = recipients(ply, kind)
	net.Start("scp.chat.msg")
	net.WriteString(kind)
	net.WriteEntity(ply)
	net.WriteString(text)
	net.Send(list)
	print(string.format("[%s] %s: %s", kind, ply:Nick(), text))
	if kind == "radio" then
		for _, p in ipairs(list) do if p ~= ply then p:EmitSound("scpsite/fx/radio_squelch.mp3", 40, 100, 0.4) end end
	end
end

-- Системное сообщение (nil — всем)
function CH.System(target, text)
	net.Start("scp.chat.msg")
	net.WriteString("system")
	net.WriteEntity(NULL)
	net.WriteString(text)
	if target then net.Send(target) else net.Broadcast() end
end

function CH.Handle(ply, text, team)
	text = string.Trim(text)
	if text == "" then return "" end
	-- команды админ-модов (!, а также неизвестные /) не трогаем
	if string.StartWith(text, "!") then return end
	local kind, body = CH.Parse(text)
	if not kind and string.StartWith(text, "/") then return end
	if body == "" then return "" end
	if (ply.scpChatAt or 0) > CurTime() then return "" end
	ply.scpChatAt = CurTime() + 0.4

	if team and not kind then kind = "radio" end
	local st = ply:SCPState()
	if not kind then
		if st == "lobby" then kind = "lobby"
		elseif st == "menu" or st == "edit" then kind = "ooc"
		else kind = "say" end
	end
	if st == "playing" and not ply:Alive() and kind ~= "ooc" then kind = "dead" end
	if kind == "radio" and (st ~= "playing") then kind = st == "lobby" and "lobby" or "ooc" end
	CH.Send(ply, kind, body)
	return ""
end

hook.Add("PlayerSay", "scp.chat", CH.Handle)

-- Сообщения из нашего окна чата приходят сетью (без ограничений консольной команды say)
net.Receive("scp.chat.say", function(_, ply)
	local text = string.sub(net.ReadString(), 1, 300)
	if CH.Handle(ply, text, false) == nil then
		-- команда другого аддона — отдаём её обычным путём
		hook.Run("PlayerSay", ply, text, false)
	end
end)

net.Receive("scp.chat.typing", function(_, ply)
	ply:SetNW2Bool("scp.typing", net.ReadBool())
end)
