--[[
	Сюжет на клиенте: цель сверху слева и метка в мире, оповещения (звук + субтитры),
	эффекты (отключение света, тревога), экран итогов.
]]

local UI = SCP.UI
local S = SCP.Story

S.Changed = S.Changed or 0

net.Receive("scp.story.state", function()
	local old = S.State.stage
	S.State = { running = net.ReadBool(), chapter = net.ReadUInt(4), stage = net.ReadUInt(6), started = net.ReadFloat(),
		collected = net.ReadUInt(6), progress = net.ReadFloat(), deadline = net.ReadFloat() }
	if net.ReadBool() then S.State.goalPos = net.ReadVector() end
	if S.State.stage ~= old and S.State.stage > 0 then
		S.Changed = RealTime()
		surface.PlaySound("scpsite/fx/objective.mp3")
	end
end)

-- ---------------------------------------------------------- оповещения --
-- Гонг громкой связи, затем голос; текст — в окне диалога «Система оповещения».
function S.Subtitle(who, text)
	SCP.Dialog.Show("pa", nil, text)
end

net.Receive("scp.story.say", function()
	local id = net.ReadString()
	local text = S.VO[id]
	if not text then return end
	local vol = GetConVar("scp_vo_volume"):GetFloat()
	sound.PlayFile("sound/scpsite/fx/pa_chime.mp3", "noblock", function(ch) if IsValid(ch) then ch:SetVolume(0.8 * vol) ch:Play() end end)
	timer.Simple(1.2, function()
		sound.PlayFile("sound/scpsite/vo/" .. id .. ".mp3", "noblock", function(ch)
			if IsValid(ch) then ch:SetVolume(math.min(vol, 1)) ch:Play() end
		end)
		SCP.Dialog.Show("pa", nil, text)
	end)
end)

-- -------------------------------------------------------------- эффекты --
local alarm
local blackoutAt, powerAt = 0, 0
function S.Dark() return blackoutAt > 0 end
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
	elseif kind == "alarm" then
		stopAlarm()
		alarm = CreateSound(me, "scpsite/fx/alarm_loop.wav")
		alarm:PlayEx(0.3, 100)
		timer.Simple(30, function() if alarm then alarm:FadeOut(4) end end)
	elseif kind == "flicker" then
		blackoutAt = RealTime() - 0.2
		surface.PlaySound("scpsite/fx/power_down.mp3")
		timer.Simple(2.5, function() blackoutAt = 0 end)
	elseif kind == "warhead" then
		stopAlarm()
		alarm = CreateSound(me, "scpsite/fx/alarm_loop.wav")
		alarm:PlayEx(0.45, 92)
		surface.PlaySound("scpsite/fx/warhead_arm.mp3")
		util.ScreenShake(me:GetPos(), 4, 3, 3, 50000)
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
	if st.kind == "survive" then
		return st.goal .. "  " .. math.floor((S.State.progress or 0) * 100) .. "%"
	end
	return st.goal
end

hook.Add("HUDPaint", "scp.story.goal", function()
	if not SCP.HUD.Playing() or not S.State.running then return end
	local st = S.Current()
	if not st then return end
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
		if st.kind == "survive" then
			surface.SetDrawColor(255, 255, 255, 25)
			surface.DrawRect(x + UI.S(14), y + UI.S(48), UI.S(220), UI.S(3))
			surface.SetDrawColor(UI.Col.amber)
			surface.DrawRect(x + UI.S(14), y + UI.S(48), UI.S(220) * (S.State.progress or 0), UI.S(3))
		end
		surface.SetAlphaMultiplier(1)
	end

	-- таймер этапа (эвакуация, боеголовка)
	local dl = S.State.deadline or 0
	if dl > 0 then
		local left = math.max(0, dl - CurTime())
		local crit = left < 20
		local pulse = crit and (0.6 + 0.4 * math.sin(RealTime() * 8)) or 1
		draw.SimpleText(string.format("%02d:%02d", math.floor(left / 60), math.floor(left % 60)), SCP.Font("title", 46), ScrW() / 2, UI.S(54),
			UI.Alpha(crit and UI.Col.red or UI.Col.text, 255 * pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("ДО КОНЦА ЭТАПА", SCP.Font("monobold", 11), ScrW() / 2, UI.S(86), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		if crit and (S.LastTick or 0) ~= math.floor(left) then
			S.LastTick = math.floor(left)
			surface.PlaySound("scpsite/fx/tick.mp3")
		end
	end

end)

-- ------------------------------------------------------------- итоги --
net.Receive("scp.story.end", function()
	local win, time, stage, chapter = net.ReadBool(), net.ReadFloat(), net.ReadUInt(6), net.ReadUInt(4)
	local ch = S.ChapterDef(chapter)
	local nstages = #ch.stages
	local scps = {}
	for _, st in ipairs(ch.stages) do for _, k in ipairs(st.spawn or {}) do scps[k] = true end end
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
		draw.SimpleText("ГЛАВА " .. ch.roman .. " · " .. string.upper(ch.title), SCP.Font("mono", 15), w / 2, h * 0.45 + UI.S(48), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local lines = {
			{ "ВРЕМЯ", string.format("%02d:%02d", math.floor(time / 60), math.floor(time % 60)) },
			{ "ЭТАП", stage .. " / " .. nstages },
		}
		for k in SortedPairs(scps) do
			lines[#lines + 1] = { "СТАТУС " .. SCP.Config.SCPs[k].name, win and "СДЕРЖАН" or "НА СВОБОДЕ" }
		end
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
