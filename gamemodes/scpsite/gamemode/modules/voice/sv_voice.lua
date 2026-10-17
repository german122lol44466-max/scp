--[[
	Голос:
	  лобби      — слышно весь свой отряд, без расстояния;
	  на задании — по расстоянию (3D), а с зажатой B — по рации всей группе;
	  погибшие   — слышат всех на задании, но живые их не слышат;
	  меню       — никто никого.
]]

local C = SCP.Config

function GM:PlayerCanHearPlayersVoice(listener, talker)
	if listener == talker then return false, false end
	local ls, ts = listener:SCPState(), talker:SCPState()
	if SCP.InEdit(listener) and SCP.InEdit(talker) then return true, false end

	if ls == "lobby" and ts == "lobby" then
		return listener:SCPLobby() == talker:SCPLobby() and listener:SCPLobby() ~= 0, false
	end

	if ls == "playing" and ts == "playing" then
		local lAlive, tAlive = listener:Alive(), talker:Alive()
		if not tAlive then return not lAlive, false end
		if not lAlive then return true, false end
		if C.VoiceRadio and talker:GetNW2Bool("scp.radio") then return true, false end
		local r = C.VoiceRange
		return listener:GetPos():DistToSqr(talker:GetPos()) <= r * r, true
	end
	return false, false
end

net.Receive("scp.voice.radio", function(_, ply)
	local on = net.ReadBool()
	ply:SetNW2Bool("scp.radio", on and ply:InGame() and ply:Alive())
end)

hook.Add("Initialize", "scp.voice", function()
	RunConsoleCommand("sv_voiceenable", "1")
	RunConsoleCommand("sv_alltalk", "0")
	if ConVarExists("mp_show_voice_icons") then RunConsoleCommand("mp_show_voice_icons", "0") end
end)
