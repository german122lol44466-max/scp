--[[
	Фразы на сервере: кто говорит, кому слышно, кулдауны.
]]

local PH = SCP.Phrases
local C = SCP.Config

local function send(ply, text)
	local list = {}
	for _, p in ipairs(player.GetAll()) do
		if p:InGame() and (p == ply or p:GetPos():DistToSqr(ply:GetPos()) <= PH.Range * PH.Range or not p:Alive()) then
			list[#list + 1] = p
		end
	end
	net.Start("scp.phrase")
	net.WriteEntity(ply)
	net.WriteString(text)
	net.Send(list)
end

function PH.Say(ply, key, vars)
	if not IsValid(ply) or not ply:InGame() or not ply:Alive() then return end
	local lines = PH.Lines[key]
	if not lines then return end
	ply.scpPhraseCD = ply.scpPhraseCD or {}
	if (ply.scpPhraseCD[key] or 0) > CurTime() or (ply.scpPhraseAny or 0) > CurTime() then return end
	ply.scpPhraseCD[key] = CurTime() + 18
	ply.scpPhraseAny = CurTime() + 2.5
	local text = lines[math.random(#lines)]
	for k, v in pairs(vars or {}) do text = string.gsub(text, "{" .. k .. "}", v) end
	send(ply, text)
end

net.Receive("scp.phrase.req", function(_, ply)
	local i = net.ReadUInt(4)
	local q = PH.Quick[i]
	if not q or not ply:InGame() or not ply:Alive() then return end
	if (ply.scpQuickAt or 0) > CurTime() then return end
	ply.scpQuickAt = CurTime() + 1.2
	send(ply, q.text)
end)

-- ---------------------------------------------------------- поводы --
hook.Add("EntityTakeDamage", "scp.phrases", function(ent, dmg)
	if not ent:IsPlayer() or not ent:InGame() then return end
	timer.Simple(0.3, function()
		if IsValid(ent) and ent:Alive() and ent:Health() < 40 then PH.Say(ent, "hurt") end
	end)
end)

hook.Add("KeyPress", "scp.phrases", function(ply, key)
	if key ~= IN_RELOAD or not ply:InGame() then return end
	local w = ply:GetActiveWeapon()
	if IsValid(w) and w:Clip1() < w:GetMaxClip1() * 0.5 and ply:GetAmmoCount(w:GetPrimaryAmmoType()) > 0 and math.random() < 0.6 then
		PH.Say(ply, "reload")
	end
end)

hook.Add("SCP.PlayerDied", "scp.phrases", function(ply)
	local best, bd
	for _, p in ipairs(player.GetAll()) do
		if p ~= ply and p:InGame() and p:Alive() then
			local d = p:GetPos():DistToSqr(ply:GetPos())
			if not bd or d < bd then best, bd = p, d end
		end
	end
	if best and bd < 1200 * 1200 then
		timer.Simple(1, function() PH.Say(best, "matedown", { name = ply:SCPName() }) end)
	end
end)

hook.Add("SCP.PickedUp", "scp.phrases", function(ply, id)
	if id == "keycard" then PH.Say(ply, "keycard") elseif math.random() < 0.25 then PH.Say(ply, "pickup") end
end)

hook.Add("SCP.StageStarted", "scp.phrases", function(i, st)
	local key = (st.startFX == "blackout" and "blackout") or (st.startFX == "breach" and "breach")
	if not key then return end
	timer.Simple(7, function()
		local alive = {}
		for _, p in ipairs(player.GetAll()) do if p:InGame() and p:Alive() then alive[#alive + 1] = p end end
		if #alive > 0 then PH.Say(alive[math.random(#alive)], key) end
	end)
end)

-- Выдохся
local wasEx = {}
timer.Create("scp.phrases.ex", 0.5, 0, function()
	for _, p in ipairs(player.GetAll()) do
		local ex = p:GetNW2Bool("scp.exhausted")
		if ex and not wasEx[p] and math.random() < 0.5 then PH.Say(p, "exhausted") end
		wasEx[p] = ex
	end
end)

-- Посмотрел на лицо SCP-096
timer.Create("scp.phrases.096", 0.3, 0, function()
	local npc = SCP.Story.NPC096
	if not IsValid(npc) then return end
	local head = npc:LookupBone("ValveBiped.Bip01_Head1")
	local hp = head and npc:GetBonePosition(head) or (npc:EyePos())
	for _, p in ipairs(player.GetAll()) do
		if p:InGame() and p:Alive() then
			local eye = p:EyePos()
			local to = hp - eye
			local d = to:Length()
			if d < 2500 and p:GetAimVector():Dot(to:GetNormalized()) > 0.96 then
				local tr = util.TraceLine({ start = eye, endpos = hp, filter = { p, npc }, mask = MASK_VISIBLE })
				if not tr.Hit and (p.scpSaw096 or 0) < CurTime() then
					p.scpSaw096 = CurTime() + 25
					SCP.Stats.Add(p, "saw_096", 1)
					PH.Say(p, "saw096")
					net.Start("scp.story.fx")
					net.WriteString("saw096")
					net.Send(p)
				end
			end
		end
	end
end)
