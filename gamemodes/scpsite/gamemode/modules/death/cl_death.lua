--[[
	Смерть «по-настоящему»:
	  0–1.2 с  — камера в глазах падающего тела, картинка дёргается и теряет цвет;
	  до 5 с   — сердце замедляется и останавливается, звук глохнет, зрение сужается до темноты;
	  потом    — тишина, чёрный экран с причиной, затем наблюдение за живыми товарищами
	             (ЛКМ/ПКМ — сменить, ждём следующего этапа).
]]

local UI = SCP.UI
local D = {}
local beatAt, beats = 0, 0
local specTarget, specIndex = nil, 1
local specAng

local function diedAgo(me)
	return CurTime() - me:GetNW2Float("scp.diedAt", CurTime())
end

local function isDead(me)
	return IsValid(me) and SCP.MyState() == "playing" and (not me:Alive() or me:GetNW2Bool("scp.dead"))
end

local function aliveMates()
	local out = {}
	for _, p in ipairs(player.GetAll()) do
		if p ~= LocalPlayer() and p:InGame() and p:Alive() then out[#out + 1] = p end
	end
	return out
end

-- ------------------------------------------------------------- камера --
hook.Add("SCP.CalcView", "scp.death", function(ply, origin, angles, fov)
	if not isDead(ply) then specTarget = nil return end
	local t = diedAgo(ply)
	if t < 6.5 then
		local rag = ply:GetRagdollEntity()
		if IsValid(rag) then
			local att = rag:LookupAttachment("eyes")
			local a = att > 0 and rag:GetAttachment(att)
			if a then
				-- голова тела, но не внутри черепа
				return { origin = a.Pos + a.Ang:Forward() * 1.5, angles = a.Ang, fov = 80, znear = 0.5 }
			end
		end
		return { origin = ply:GetPos() + Vector(0, 0, 10), angles = Angle(-10, angles.y, 70), fov = 80 }
	end
	-- наблюдение
	local mates = aliveMates()
	if #mates == 0 then return { origin = ply:GetPos() + Vector(0, 0, 80), angles = angles, fov = 70 } end
	specIndex = (specIndex - 1) % #mates + 1
	specTarget = mates[specIndex]
	local center = specTarget:GetPos() + Vector(0, 0, 60)
	specAng = angles
	local want = center - angles:Forward() * 110 + angles:Right() * 18
	local tr = util.TraceHull({ start = center, endpos = want, mins = Vector(-6, -6, -6), maxs = Vector(6, 6, 6), filter = { specTarget, ply }, mask = MASK_SOLID_BRUSHONLY })
	return { origin = tr.HitPos, angles = angles, fov = 70, drawviewer = false }
end)

hook.Add("PlayerBindPress", "scp.death.spec", function(ply, bind, pressed)
	if not isDead(ply) or not pressed or diedAgo(ply) < 6.5 then return end
	if bind == "+attack" then specIndex = specIndex + 1 UI.Sound("swipe") return true end
	if bind == "+attack2" then specIndex = specIndex - 1 UI.Sound("swipe") return true end
end)

-- ----------------------------------------------------- звук и картинка --
local muffled = false
hook.Add("Think", "scp.death.sound", function()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	local dead = isDead(me)
	if dead and not muffled then
		muffled = true
		me:SetDSP(31, false)
		beats, beatAt = 0, RealTime() + 0.2
		surface.PlaySound("scpsite/fx/death_hit.mp3")
	elseif not dead and muffled then
		muffled = false
		me:SetDSP(0, false)
	end
	if not dead then return end
	-- сердце: 6 ударов, каждый реже и тише
	if beats < 6 and RealTime() >= beatAt then
		beats = beats + 1
		sound.Play("scpsite/fx/heartbeat.mp3", me:GetPos(), 75, 100 - beats * 4, 1 - beats * 0.14)
		beatAt = RealTime() + 0.75 + beats * 0.28
	end
	if diedAgo(me) > 6.5 and muffled ~= "spec" then
		muffled = "spec"
		me:SetDSP(0, false)
	end
end)

hook.Add("RenderScreenspaceEffects", "scp.death", function()
	local me = LocalPlayer()
	if not isDead(me) then return end
	local t = diedAgo(me)
	if t < 6.5 then
		local k = math.Clamp(t / 4.5, 0, 1)
		DrawColorModify({
			["$pp_colour_addr"] = 0.08 * (1 - k), ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = -0.05 - k * 0.25, ["$pp_colour_contrast"] = 1 + k * 0.2,
			["$pp_colour_colour"] = 1 - k * 0.95, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
		})
		DrawMotionBlur(0.15, 0.9 * (1 - k * 0.5), 0.01)
		DrawToyTown(2, ScrH() * (0.3 + k * 0.4))
	else
		DrawColorModify({
			["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = -0.04, ["$pp_colour_contrast"] = 1.05,
			["$pp_colour_colour"] = 0.15, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
		})
	end
end)

-- -------------------------------------------------------------- экран --
hook.Add("HUDPaint", "scp.death", function()
	local me = LocalPlayer()
	if not isDead(me) then return end
	local w, h = ScrW(), ScrH()
	local t = diedAgo(me)

	if t < 6.5 then
		-- зрение сужается: виньетка становится всё плотнее, в конце — темнота
		local k = math.Clamp(t / 4.5, 0, 1)
		for i = 1, 1 + math.floor(k * 4) do UI.Vignette(0, 0, w, h, 255) end
		surface.SetDrawColor(0, 0, 0, 255 * math.Clamp((t - 3.2) / 1.6, 0, 1))
		surface.DrawRect(0, 0, w, h)
		-- красная вспышка удара
		surface.SetDrawColor(120, 0, 0, 160 * math.Clamp(1 - t / 0.6, 0, 1))
		surface.DrawRect(0, 0, w, h)
		-- в полной темноте: текст
		local ta = math.Clamp((t - 4.6) / 0.6, 0, 1) * math.Clamp((6.5 - t) / 0.4, 0, 1)
		if ta > 0 then
			surface.SetAlphaMultiplier(ta)
			draw.SimpleText("СИГНАЛ ЖИЗНЕДЕЯТЕЛЬНОСТИ ПОТЕРЯН", SCP.Font("monobold", 18), w / 2, h / 2 - UI.S(14), UI.Col.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(string.upper(me:SCPName()) .. " · " .. me:GetNW2String("scp.cause", ""), SCP.Font("mono", 14), w / 2, h / 2 + UI.S(16), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			surface.SetAlphaMultiplier(1)
		end
		return
	end

	-- наблюдение: вход из темноты
	surface.SetDrawColor(0, 0, 0, 255 * math.Clamp(1 - (t - 6.5) / 1.2, 0, 1))
	surface.DrawRect(0, 0, w, h)
	UI.Vignette(0, 0, w, h, 255)
	UI.Scanlines(0, 0, w, h, 26)

	-- полосы сверху/снизу как у камеры наблюдения
	surface.SetDrawColor(0, 0, 0, 230)
	surface.DrawRect(0, 0, w, UI.S(70))
	surface.DrawRect(0, h - UI.S(90), w, UI.S(90))
	local blink = math.floor(RealTime() * 1.5) % 2 == 0
	if blink then UI.Circle(UI.S(40), UI.S(35), UI.S(6), UI.Col.red) end
	draw.SimpleText("НАБЛЮДЕНИЕ", SCP.Font("monobold", 15), UI.S(56), UI.S(35), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(os.date("%H:%M:%S"), SCP.Font("mono", 14), w - UI.S(40), UI.S(35), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if IsValid(specTarget) then
		draw.SimpleText(specTarget:SCPName(), SCP.Font("title", 26), w / 2, h - UI.S(60), UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("ЗДОРОВЬЕ " .. math.max(0, specTarget:Health()) .. "%  ·  ЛКМ / ПКМ — СМЕНИТЬ", SCP.Font("mono", 12), w / 2, h - UI.S(30), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText("В ЖИВЫХ НИКОГО НЕ ОСТАЛОСЬ", SCP.Font("monobold", 15), w / 2, h - UI.S(46), UI.Col.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	draw.SimpleText("Вы вернётесь в строй на следующем этапе задания", SCP.Font("regular", 14), w / 2, UI.S(35), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
