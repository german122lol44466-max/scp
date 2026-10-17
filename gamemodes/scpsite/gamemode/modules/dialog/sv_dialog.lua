--[[
	Диалоги на сервере: DG.Send(кому, who, говорящий, текст, звук), крики на G.
]]

local DG = SCP.Dialog

-- who: "player" (говорит speaker), "command", "pa", "self"
function DG.Send(targets, who, speaker, text, snd)
	net.Start("scp.dialog")
	net.WriteString(who)
	net.WriteEntity(IsValid(speaker) and speaker or NULL)
	net.WriteString(text)
	net.WriteString(snd or "")
	net.Send(targets)
end

-- Всем, кто рядом с говорящим (и погибшим-наблюдателям)
function DG.Near(speaker, range)
	local out = {}
	range = range or DG.Range
	for _, p in ipairs(player.GetAll()) do
		if p:InGame() and (p == speaker or not p:Alive() or p:GetPos():DistToSqr(speaker:GetPos()) <= range * range) then
			out[#out + 1] = p
		end
	end
	return out
end

net.Receive("scp.shout", function(_, ply)
	local i = net.ReadUInt(5)
	local s = DG.Shouts[i]
	if not s or not ply:InGame() or not ply:Alive() then return end
	if (ply.scpShoutAt or 0) > CurTime() then return end
	ply.scpShoutAt = CurTime() + 2.5
	local file = "scpsite/mtf/" .. s.snd .. (s.n > 1 and math.random(s.n) or "") .. ".mp3"
	ply:EmitSound(file, 95, math.random(97, 103), 1, CHAN_VOICE)
	DG.Send(DG.Near(ply), "player", ply, s.text, "")
	SCP.Phrases.Bubble(ply, s.text)
end)
