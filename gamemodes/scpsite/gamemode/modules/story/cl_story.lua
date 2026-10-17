--[[
	Сюжет на клиенте: цель сверху слева и метка в мире, оповещения (звук + субтитры),
	эффекты (отключение света, тревога), экран итогов.
]]

local UI = SCP.UI
local S = SCP.Story

S.Changed = S.Changed or 0

net.Receive("scp.story.state", function()
	local old = S.State.stage
	S.State = { running = net.ReadBool(), stage = net.ReadUInt(6), started = net.ReadFloat(), collected = net.ReadUInt(6) }
	if net.ReadBool() then S.State.goalPos = net.ReadVector() end
	if S.State.stage ~= old and S.State.stage > 0 then
		S.Changed = RealTime()
		surface.PlaySound("scpsite/fx/objective.mp3")
	end
end)

-- ---------------------------------------------------------- оповещения --
local subs = {}
function S.Subtitle(who, text, dur, col)
	subs[#subs + 1] = { who = who, text = text, born = RealTime(), dur = dur or math.max(4, utf8.len(text) / 14), col = col }
	if #subs > 3 then table.remove(subs, 1) end
end

net.Receive("scp.story.say", function()
	local id = net.ReadString()
	local text = S.VO[id]
	if not text then return end
	surface.PlaySound("scpsite/fx/pa_chime.mp3")
	timer.Simple(1.1, function()
		sound.PlayFile("sound/scpsite/vo/" .. id .. ".mp3", "noblock", function(ch)
			if IsValid(ch) then ch:SetVolume(0.9) ch:Play() end
		end)
		S.Subtitle("ОПОВЕЩЕНИЕ", text, nil, UI.Col.amber)
	end)
end)

hook.Add("HUDPaint", "scp.story.subs", function()
	if SCP.MyState() ~= "playing" then return end
	local now = RealTime()
	local font = SCP.Font("medium", 18)
	local y = ScrH() - UI.S(200)
	for i = #subs, 1, -1 do
		local s = subs[i]
		local t = now - s.born
		if t > s.dur + 0.5 then table.remove(subs, i)
		else
			local a = math.min(t / 0.25, 1) * math.min((s.dur + 0.5 - t) / 0.5, 1)
			local lines = UI.Wrap(s.text, font, UI.S(820))
			local h = #lines * UI.S(26) + UI.S(34)
			local w = UI.S(880)
			local x = ScrW() / 2 - w / 2
			y = y - h - UI.S(8)
			surface.SetAlphaMultiplier(a)
			surface.SetDrawColor(0, 0, 0, 170)
			surface.DrawRect(x, y, w, h)
			draw.SimpleText(s.who, SCP.Font("monobold", 12), ScrW() / 2, y + UI.S(14), s.col or UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			for li, l in ipairs(lines) do
				draw.SimpleText(l, font, ScrW() / 2, y + UI.S(28) + (li - 1) * UI.S(26), UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
			surface.SetAlphaMultiplier(1)
		end
	end
end)

-- -------------------------------------------------------------- эффекты --
local alarm
local blackoutAt, powerAt = 0, 0
local function stopAlarm() if alarm then alarm:Stop() alarm = nil end end

net.Receive("scp.story.fx", function()
	local kind = net.ReadString()
	local me = LocalPlayer()
	if kind == "blackout" then
		blackoutAt = RealTime()
		surface.PlaySound("scpsite/fx/power_down.mp3")
		timer.Simple(0.3, function() render.RedownloadAllLightmaps(true) end)
	elseif kind == "power" then
		powerAt = RealTime()
		blackoutAt = 0
		surface.PlaySound("scpsite/fx/generator_on.mp3")
		timer.Simple(0.3, function() render.RedownloadAllLightmaps(true) end)
	elseif kind == "breach" then
		stopAlarm()
		alarm = CreateSound(me, "scpsite/fx/alarm_loop.wav")
		alarm:PlayEx(0.35, 100)
		timer.Simple(40, function() if alarm then alarm:FadeOut(4) end end)
		surface.PlaySound("scpsite/fx/horror" .. math.random(1, 4) .. ".mp3")
	elseif kind == "contain" then
		stopAlarm()
		surface.PlaySound("scpsite/fx/lockdown.mp3")
	elseif kind == "saw096" then
		hook.Run("SCP.Saw096")
	elseif kind == "reset" then
		stopAlarm()
		blackoutAt = 0
		timer.Simple(0.3, function() render.RedownloadAllLightmaps(true) end)
	end
end)

-- В темноте — чуть синее и зернистее; мерцание при переключении
hook.Add("RenderScreenspaceEffects", "scp.story.dark", function()
	if SCP.MyState() ~= "playing" or blackoutAt == 0 then return end
	local t = RealTime() - blackoutAt
	local flick = t < 1.5 and (math.random() < 0.4 and -0.25 or 0) or 0
	DrawColorModify({
		["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0.01,
		["$pp_colour_brightness"] = -0.03 + flick, ["$pp_colour_contrast"] = 1.08,
		["$pp_colour_colour"] = 0.6, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0.05,
	})
end)

-- ------------------------------------------------------------ цель (HUD) --
local function goalText(st)
	if st.kind == "collect" then
		return st.goal .. "  " .. (S.State.collected or 0) .. "/" .. st.count
	end
	return st.goal
end

hook.Add("HUDPaint", "scp.story.goal", function()
	if SCP.MyState() ~= "playing" or not S.State.running then return end
	local st = S.Current()
	if not st then return end
	local me = LocalPlayer()
	local since = RealTime() - S.Changed
	-- первые 6 секунд — крупно по центру, потом — компактно слева сверху
	if since < 6 then
		local a = math.min(since / 0.5, 1) * math.min((6 - since) / 0.8, 1)
		surface.SetAlphaMultiplier(a)
		local cy = ScrH() * 0.28
		draw.SimpleText(S.Chapter .. " · ЭТАП " .. S.State.stage .. "/" .. #S.Stages, SCP.Font("monobold", 14), ScrW() / 2, cy - UI.S(40), UI.Col.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(string.upper(st.title), SCP.Font("title", 54), ScrW() / 2, cy, UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(255, 255, 255, 60)
		surface.DrawRect(ScrW() / 2 - UI.S(120), cy + UI.S(36), UI.S(240), 1)
		draw.SimpleText(goalText(st), SCP.Font("medium", 18), ScrW() / 2, cy + UI.S(60), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
	end

	local a = math.Clamp((since - 5) / 0.6, 0, 1)
	if a > 0 then
		surface.SetAlphaMultiplier(a)
		local x, y = UI.S(36), UI.S(34)
		surface.SetDrawColor(UI.Col.red)
		surface.DrawRect(x, y, UI.S(2), UI.S(46))
		draw.SimpleText(string.upper(st.title) .. "  ·  " .. S.State.stage .. "/" .. #S.Stages, SCP.Font("monobold", 12), x + UI.S(14), y + UI.S(10), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(goalText(st), SCP.Font("semibold", 18), x + UI.S(14), y + UI.S(32), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
	end

	-- метка цели в мире
	local pos = S.State.goalPos
	if pos and me:Alive() then
		local d = me:GetPos():Distance(pos)
		local sc = pos:ToScreen()
		local m = math.Round(d / 52.5)
		local x, y = sc.x, sc.y
		local onScreen = sc.visible and x > 0 and x < ScrW() and y > 0 and y < ScrH()
		if not onScreen then
			-- прижать к краю
			local dir = (pos - EyePos()):GetNormalized()
			local ang = EyeAngles()
			local rx, ry = dir:Dot(ang:Right()), -dir:Dot(ang:Up())
			local len = math.sqrt(rx * rx + ry * ry)
			if len < 0.001 then rx, ry, len = 0, 1, 1 end
			x = ScrW() / 2 + rx / len * ScrW() * 0.42
			y = ScrH() / 2 + ry / len * ScrH() * 0.4
		end
		local fade = math.Clamp((d - 100) / 200, 0, 1) * 0.85
		if fade > 0 then
			local s = UI.S(10)
			surface.SetDrawColor(230, 180, 60, 230 * fade)
			draw.NoTexture()
			surface.DrawPoly({ { x = x, y = y - s }, { x = x + s, y = y }, { x = x, y = y + s }, { x = x - s, y = y } })
			draw.SimpleTextOutlined(m .. " м", SCP.Font("monobold", 13), x, y + UI.S(20), Color(230, 230, 224, 230 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 160 * fade))
		end
	end
end)

-- ------------------------------------------------------------- итоги --
net.Receive("scp.story.end", function()
	local win, time, stage = net.ReadBool(), net.ReadFloat(), net.ReadUInt(6)
	stopAlarm()
	if IsValid(S.EndPanel) then S.EndPanel:Remove() end
	surface.PlaySound(win and "scpsite/music/ending.mp3" or "scpsite/fx/horror1.mp3")
	local p = vgui.Create("DPanel")
	S.EndPanel = p
	p:SetSize(ScrW(), ScrH())
	p.Born = RealTime()
	p:SetMouseInputEnabled(false)
	p.Paint = function(s, w, h)
		local t = RealTime() - s.Born
		if t > 11.5 then s:Remove() return end
		local a = UI.Ease(t / 1.2)
		surface.SetDrawColor(0, 0, 0, 235 * a)
		surface.DrawRect(0, 0, w, h)
		UI.Scanlines(0, 0, w, h, 30 * a)
		surface.SetAlphaMultiplier(UI.Ease((t - 0.8) / 0.8))
		UI.Logo(w / 2, h * 0.3, UI.S(90), 230, true)
		draw.SimpleText(win and "ЗАДАНИЕ ВЫПОЛНЕНО" or "ЗАДАНИЕ ПРОВАЛЕНО", SCP.Font("title", 60), w / 2, h * 0.45,
			win and UI.Col.text or UI.Col.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(S.Title .. " · " .. S.Chapter, SCP.Font("mono", 15), w / 2, h * 0.45 + UI.S(48), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local lines = {
			{ "ВРЕМЯ", string.format("%02d:%02d", math.floor(time / 60), math.floor(time % 60)) },
			{ "ЭТАП", stage .. " / " .. #S.Stages },
			{ "СТАТУС SCP-096", win and "ОБЕЗДВИЖЕН" or "НА СВОБОДЕ" },
		}
		for i, l in ipairs(lines) do
			local y = h * 0.58 + (i - 1) * UI.S(30)
			draw.SimpleText(l[1], SCP.Font("mono", 14), w / 2 - UI.S(12), y, UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			draw.SimpleText(l[2], SCP.Font("monobold", 14), w / 2 + UI.S(12), y, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		draw.SimpleText("Возвращение в лобби через " .. math.max(0, math.ceil(11.5 - t)) .. " с", SCP.Font("regular", 14), w / 2, h * 0.82, UI.Col.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
	end
end)

-- ------------------------------------------------- фоновая музыка/эмбиент --
local amb, ambVol = nil, 0
hook.Add("Think", "scp.story.ambient", function()
	local want = (SCP.MyState() == "playing" and S.State.running) and GetConVar("scp_music"):GetFloat() * 0.35 or 0
	if want > 0 and not amb and not S.AmbLoading then
		S.AmbLoading = true
		sound.PlayFile("sound/scpsite/music/ambient.mp3", "noblock noplay", function(ch)
			S.AmbLoading = false
			if not IsValid(ch) then return end
			amb = ch
			ch:EnableLooping(true)
			ch:SetVolume(0)
			ch:Play()
		end)
	end
	if not IsValid(amb) then return end
	ambVol = UI.Approach(ambVol, want, 0.6)
	amb:SetVolume(ambVol)
	if want == 0 and ambVol < 0.005 then amb:Stop() amb = nil end
end)

-- Редкие «страшные» звуки в тишине
timer.Create("scp.story.stings", 45, 0, function()
	if SCP.MyState() == "playing" and S.State.running and S.State.stage >= 2 and math.random() < 0.5 then
		surface.PlaySound("scpsite/fx/horror" .. math.random(1, 8) .. ".mp3")
	end
end)
