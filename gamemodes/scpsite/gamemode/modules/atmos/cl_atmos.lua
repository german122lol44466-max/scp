--[[
	Атмосфера комплекса (только на задании):
	- случайные звуки коридоров (SCP:CB: гул, удары, шаги вдалеке, двери, капли) — с разных сторон;
	- точки «Источник звука комплекса» — постоянный гул/вентиляция/серверы рядом с точкой (3D);
	- точки «Мигающая лампа» — живой свет, который дёргается, гаснет и жужжит;
	- пыль в воздухе вокруг игрока, туман, холодная цветокоррекция, плёночное зерно;
	- сердцебиение, когда рядом SCP.
	Громкость — ESC → Настройки → «Атмосфера комплекса»; эффекты картинки — «Зерно и цветокоррекция».
]]

local UI = SCP.UI
local Set = SCP.Settings
local P = SCP.Points

local function active()
	return SCP.MyState() == "playing" and IsValid(LocalPlayer())
end

local function vol() return Set.Num("sfx") end

-- ---------------------------------------------------------- случайные звуки --
local ONESHOTS = {}
for i = 1, 11 do ONESHOTS[#ONESHOTS + 1] = "scpsite/amb/zone1_" .. i .. ".mp3" end
for i = 1, 11 do ONESHOTS[#ONESHOTS + 1] = "scpsite/amb/zone2_" .. i .. ".mp3" end
for i = 1, 12 do ONESHOTS[#ONESHOTS + 1] = "scpsite/amb/zone3_" .. i .. ".mp3" end
local nextShot = 0

hook.Add("Think", "scp.atmos.oneshot", function()
	if not active() or RealTime() < nextShot then return end
	nextShot = RealTime() + math.Rand(14, 32)
	local snd = ONESHOTS[math.random(#ONESHOTS)]
	local dir = VectorRand()
	dir.z = math.abs(dir.z) * 0.3
	dir:Normalize()
	sound.PlayFile("sound/" .. snd, "3d noblock", function(ch)
		if not IsValid(ch) then return end
		ch:SetPos(EyePos() + dir * math.Rand(300, 700))
		ch:SetVolume(0.55 * vol())
		ch:Set3DFadeDistance(200, 2000)
		ch:Play()
	end)
end)

-- --------------------------------------------------- источники звука (точки) --
local LOOPS = { "scpsite/amb/drone.mp3", "scpsite/amb/vent.mp3", "scpsite/amb/servers.mp3", "scpsite/amb/fan.mp3", "scpsite/amb/drip.mp3" }
local chans = {}   -- [index точки] = channel

hook.Add("Think", "scp.atmos.loops", function()
	local list = P.Get("ambient")
	local me = LocalPlayer()
	for i, p in ipairs(list) do
		local near = active() and me:GetPos():DistToSqr(p.pos) < 1400 * 1400
		local ch = chans[i]
		if near and ch == nil then
			chans[i] = false -- загружается
			sound.PlayFile("sound/" .. LOOPS[(i - 1) % #LOOPS + 1], "3d noblock noplay", function(c)
				if not IsValid(c) then chans[i] = nil return end
				c:SetPos(p.pos)
				c:EnableLooping(true)
				c:Set3DFadeDistance(120, 1200)
				c:SetVolume(0.7 * vol())
				c:Play()
				chans[i] = c
			end)
		elseif not near and ch then
			ch:Stop()
			chans[i] = nil
		elseif ch then
			ch:SetVolume(0.7 * vol())
		end
	end
	for i, ch in pairs(chans) do
		if not list[i] and ch then ch:Stop() chans[i] = nil end
	end
end)

-- ------------------------------------------------------- мигающие лампы --
local lamps = {}
hook.Add("Think", "scp.atmos.flicker", function()
	if not active() then return end
	local me = LocalPlayer()
	local t = RealTime()
	for i, p in ipairs(P.Get("flicker")) do
		if me:GetPos():DistToSqr(p.pos) < 1600 * 1600 then
			local l = lamps[i] or { on = true, next = 0, buzz = 0 }
			lamps[i] = l
			if t > l.next then
				l.on = not l.on or math.random() < 0.7
				l.next = t + (l.on and math.Rand(0.05, 1.8) or math.Rand(0.03, 0.25))
				if not l.on and t > l.buzz then
					l.buzz = t + 2
					sound.Play("scpsite/amb/buzz.mp3", p.pos, 60, math.random(95, 105), 0.4 * vol())
				end
			end
			if l.on then
				local d = DynamicLight(4000 + i)
				if d then
					d.pos = p.pos + Vector(0, 0, 60)
					d.r, d.g, d.b = 255, 236, 200
					d.brightness = 1.2 + math.Rand(-0.2, 0.2)
					d.Decay = 2000
					d.Size = 340
					d.DieTime = CurTime() + 0.1
				end
			end
		end
	end
end)

-- ------------------------------------------------------------------ пыль --
local emitter
local nextDust = 0
hook.Add("Think", "scp.atmos.dust", function()
	if not active() or not Set.Bool("grain") or RealTime() < nextDust then return end
	nextDust = RealTime() + 0.08
	emitter = emitter or ParticleEmitter(EyePos())
	if not emitter then return end
	local pos = EyePos() + VectorRand() * 160
	local p = emitter:Add("particle/particle_glow_04", pos)
	if p then
		p:SetDieTime(math.Rand(4, 7))
		p:SetStartAlpha(0)
		p:SetEndAlpha(0)
		p:SetStartSize(math.Rand(0.4, 0.9))
		p:SetEndSize(0.3)
		p:SetColor(220, 220, 210)
		p:SetVelocity(VectorRand() * 3 + Vector(0, 0, -1))
		p:SetAirResistance(10)
		p:SetThinkFunction(function(pa)
			local life = pa:GetLifeTime() / pa:GetDieTime()
			pa:SetStartAlpha(70 * math.sin(life * math.pi))
			pa:SetNextThink(CurTime() + 0.05)
		end)
		p:SetNextThink(CurTime())
	end
end)

-- -------------------------------------------------------- туман и цвет --
local function fog(scale)
	if not active() or not Set.Bool("grain") then return end
	local dark = SCP.Story.Dark and SCP.Story.Dark() or false
	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(dark and 120 or 350 * (scale or 1))
	render.FogEnd(dark and 1600 or 4200 * (scale or 1))
	render.FogMaxDensity(dark and 0.85 or 0.55)
	render.FogColor(14, 16, 20)
	return true
end
hook.Add("SetupWorldFog", "scp.atmos", function() return fog(1) end)
hook.Add("SetupSkyboxFog", "scp.atmos", function(scale) return fog(scale) end)

hook.Add("RenderScreenspaceEffects", "scp.atmos.grade", function()
	if not active() or not Set.Bool("grain") then return end
	DrawColorModify({
		["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0.002, ["$pp_colour_addb"] = 0.008,
		["$pp_colour_brightness"] = -0.015, ["$pp_colour_contrast"] = 1.07,
		["$pp_colour_colour"] = 0.82, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0.02,
	})
	DrawSharpen(0.6, 0.6)
end)

hook.Add("HUDPaintBackground", "scp.atmos.grain", function()
	if not active() or not Set.Bool("grain") then return end
	UI.Grain(0, 0, ScrW(), ScrH(), 9)
end)

-- --------------------------------------------------- сердце рядом с SCP --
local nextBeat = 0
hook.Add("Think", "scp.atmos.heart", function()
	local me = LocalPlayer()
	if not active() or not me:Alive() or RealTime() < nextBeat then return end
	local best
	for _, s in ipairs(SCP.FindSCPs()) do
		local d = s.ent:GetPos():Distance(me:GetPos())
		if not best or d < best then best = d end
	end
	if not best or best > 900 then nextBeat = RealTime() + 0.5 return end
	local k = 1 - best / 900
	surface.PlaySound("scpsite/fx/heartbeat.mp3")
	nextBeat = RealTime() + Lerp(k, 1.2, 0.42)
end)
