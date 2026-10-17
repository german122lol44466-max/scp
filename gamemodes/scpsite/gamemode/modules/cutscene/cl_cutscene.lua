--[[
	Катсцена на клиенте: плавный пролёт камеры (сплайн Катмулла–Рома по точкам), кинорамка,
	титр главы, субтитры, затемнения в начале и конце; flash = true — белая вспышка (детонация).
	Предпросмотр в редакторе: кнопка «Проиграть» у точки катсцены или scp_cutscene <id>.
]]

local UI = SCP.UI
local CS = {}
SCP.Cutscene = CS
local cur

local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function lerpAngle(t, a, b)
	return Angle(Lerp(t, a.p, a.p + math.AngleDifference(b.p, a.p)), Lerp(t, a.y, a.y + math.AngleDifference(b.y, a.y)), 0)
end

function CS.Play(id, local_)
	local def = SCP.Story.Cutscenes[id]
	local pts = SCP.Points.Get("cs_" .. id)
	if not def or #pts < 2 then return end
	cur = { id = id, def = def, pts = pts, born = RealTime(), local_ = local_, skip = false }
	surface.PlaySound("scpsite/fx/cutscene_hit.mp3")
end

function CS.Stop()
	cur = nil
end

function CS.Active() return cur ~= nil end

net.Receive("scp.cutscene", function()
	local id = net.ReadString()
	if id == "" then CS.Stop() else CS.Play(id) end
end)

concommand.Add("scp_cutscene_preview", function(_, _, args) CS.Play(args[1] or "", true) end)

local function position(t)
	local pts = cur.pts
	local n = #pts
	local f = math.Clamp(t, 0, 1) * (n - 1)
	local i = math.min(math.floor(f) + 1, n - 1)
	local u = UI.EaseInOut(f - (i - 1))
	local p0 = pts[math.max(i - 1, 1)].pos
	local p1, p2 = pts[i].pos, pts[i + 1].pos
	local p3 = pts[math.min(i + 2, n)].pos
	local u2 = f - (i - 1)
	return catmull(p0, p1, p2, p3, u2), lerpAngle(u, pts[i].ang, pts[i + 1].ang)
end

hook.Add("SCP.CalcView", "scp.cutscene", function()
	if not cur then return end
	local t = (RealTime() - cur.born) / cur.def.duration
	if t > 1.08 then cur = nil return end
	local pos, ang = position(t)
	-- лёгкое «ручное» дыхание камеры
	local r = RealTime()
	ang = ang + Angle(math.sin(r * 0.9) * 0.4, math.sin(r * 0.6) * 0.5, math.sin(r * 0.7) * 0.3)
	return { origin = pos, angles = ang, fov = 62, drawviewer = true }
end)

hook.Add("HUDShouldDraw", "scp.cutscene", function(name)
	if cur and name ~= "CHudGMod" then return false end
end)

hook.Add("PlayerBindPress", "scp.cutscene", function(ply, bind, pressed)
	if not cur then return end
	if pressed and string.find(bind, "+jump", 1, true) then
		if cur.local_ then cur = nil return true end
		if not cur.skip then
			cur.skip = true
			net.Start("scp.cutscene.skip")
			net.SendToServer()
			UI.Sound("click")
		end
	end
	return true
end)

-- Поверх всего (и поверх HUD других модулей)
hook.Add("PostRenderVGUI", "scp.cutscene", function()
	if not cur then return end
	local w, h = ScrW(), ScrH()
	local el = RealTime() - cur.born
	local dur = cur.def.duration
	-- кинорамка
	local bar = h * 0.12 * UI.Ease(el / 0.8) * math.Clamp((dur + 0.8 - el) / 0.8, 0, 1)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, w, bar)
	surface.DrawRect(0, h - bar, w, bar)
	UI.Vignette(0, 0, w, h, 200)
	UI.Grain(0, 0, w, h, 12)
	-- затемнение в начале/конце
	local fade = math.max(1 - el / 0.9, (el - dur + 0.6) / 0.6)
	if fade > 0 then
		surface.SetDrawColor(0, 0, 0, 255 * math.Clamp(fade, 0, 1))
		surface.DrawRect(0, 0, w, h)
	end
	-- вспышка
	if cur.def.flash then
		local f = math.Clamp(1 - math.abs(el - dur * 0.3) / 1.2, 0, 1)
		if f > 0 then
			surface.SetDrawColor(255, 250, 235, 255 * f)
			surface.DrawRect(0, 0, w, h)
		end
		if not cur.flashed and el > dur * 0.3 - 0.2 then
			cur.flashed = true
			surface.PlaySound("scpsite/fx/detonation.mp3")
			util.ScreenShake(LocalPlayer():GetPos(), 20, 8, 4, 50000)
		end
	end
	-- титр
	local ta = math.Clamp((el - 1) / 0.8, 0, 1) * math.Clamp((5 - el) / 0.8, 0, 1)
	if ta > 0 then
		surface.SetAlphaMultiplier(ta)
		UI.Logo(UI.S(110), h - bar - UI.S(96), UI.S(52), 220)
		draw.SimpleText(cur.def.title, SCP.Font("title", 56), UI.S(150), h - bar - UI.S(110), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(string.upper(cur.def.sub or ""), SCP.Font("mono", 14), UI.S(153), h - bar - UI.S(68), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
	end
	-- субтитры (и озвучка реплики в момент появления)
	cur.said = cur.said or {}
	for i, l in ipairs(cur.def.lines or {}) do
		local lt = el - l[1]
		if lt > 0 and not cur.said[i] then
			cur.said[i] = true
			SCP.Dialog.PlayVoice(l[3])
		end
		local ld = math.max(3.5, utf8.len(l[3]) / 13)
		if lt > 0 and lt < ld then
			local a = math.min(lt / 0.3, 1) * math.min((ld - lt) / 0.4, 1)
			surface.SetAlphaMultiplier(a)
			draw.SimpleText(string.upper(l[2]), SCP.Font("monobold", 12), w / 2, h - bar + UI.S(26), UI.Col.amber, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(l[3], SCP.Font("medium", 20), w / 2, h - bar + UI.S(54), UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			surface.SetAlphaMultiplier(1)
		end
	end
	-- пропуск
	draw.SimpleText(cur.skip and "ОЖИДАНИЕ ОТРЯДА…" or "[ПРОБЕЛ] ПРОПУСТИТЬ", SCP.Font("mono", 11), w - UI.S(30), bar / 2, Color(255, 255, 255, 90), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)
