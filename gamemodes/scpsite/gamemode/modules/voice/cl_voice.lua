--[[
	Голос на клиенте: без стандартных панелей.
	- свой индикатор снизу по центру (кольца «дышат» от громкости), «РАЦИЯ» при зажатой B;
	- над говорящими рядом — значок микрофона;
	- слева — кто говорит по рации, с щелчком рации в начале и конце.
]]

local UI = SCP.UI
local speaking = {}

function GM:PlayerStartVoice(ply)
	speaking[ply] = RealTime()
	if ply ~= LocalPlayer() and ply:GetNW2Bool("scp.radio") and SCP.MyState() == "playing" then
		surface.PlaySound("scpsite/fx/radio_squelch.mp3")
	end
end

function GM:PlayerEndVoice(ply)
	if ply ~= LocalPlayer() and ply:GetNW2Bool("scp.radio") and SCP.MyState() == "playing" then
		surface.PlaySound("scpsite/fx/radio_squelch.mp3")
	end
	speaking[ply] = nil
end

-- B — рация (push-to-talk)
local radioKey = CreateClientConVar("scp_radio_key", tostring(KEY_B), true, false, "Клавиша рации (код KEY_*)")
local radioDown = false

local function setRadio(on)
	if radioDown == on then return end
	radioDown = on
	net.Start("scp.voice.radio")
	net.WriteBool(on)
	net.SendToServer()
	if on then
		surface.PlaySound("scpsite/fx/radio_squelch.mp3")
		RunConsoleCommand("+voicerecord")
	else
		RunConsoleCommand("-voicerecord")
	end
end

hook.Add("PlayerButtonDown", "scp.voice.radio", function(ply, key)
	if key ~= radioKey:GetInt() or not IsFirstTimePredicted() then return end
	if SCP.MyState() ~= "playing" or not ply:Alive() or vgui.GetKeyboardFocus() or gui.IsGameUIVisible() then return end
	setRadio(true)
end)

hook.Add("PlayerButtonUp", "scp.voice.radio", function(ply, key)
	if key ~= radioKey:GetInt() or not IsFirstTimePredicted() then return end
	setRadio(false)
end)

-- ---------------------------------------------------------------- HUD --
local anim, level = 0, 0
local waves = {}

hook.Add("HUDPaint", "scp.voice.self", function()
	if SCP.MyState() ~= "playing" then return end
	local me = LocalPlayer()
	local talking = me:IsSpeaking() or speaking[me] ~= nil
	anim = UI.Approach(anim, talking and 1 or 0, talking and 14 or 8)
	if anim < 0.01 then return end
	local vol = me:VoiceVolume()
	if vol <= 0 and talking then vol = 0.2 + math.abs(math.sin(RealTime() * 7)) * 0.2 end
	level = UI.Approach(level, math.Clamp(vol * 2.4, 0, 1), 18)
	local radio = radioDown
	local col = radio and UI.Col.amber or UI.Col.text
	local x, y = ScrW() / 2, ScrH() - UI.S(120)
	if level > 0.45 and (waves[#waves] or 0) < RealTime() - 0.22 then waves[#waves + 1] = RealTime() end
	for i = #waves, 1, -1 do
		local t = (RealTime() - waves[i]) / 0.9
		if t > 1 then table.remove(waves, i)
		else UI.Ring(x, y, UI.S(20) + t * UI.S(24), Color(col.r, col.g, col.b, 90 * (1 - t) * anim)) end
	end
	local r = (UI.S(17) + level * UI.S(6)) * (0.6 + 0.4 * UI.Ease(anim))
	UI.Circle(x, y, r + UI.S(3), Color(0, 0, 0, 110 * anim))
	UI.Ring(x, y, r, Color(col.r, col.g, col.b, 220 * anim))
	UI.DrawIcon(radio and "radio" or "mic", x, y, r * 0.95, Color(col.r, col.g, col.b, 255 * anim))
	draw.SimpleText(radio and "РАЦИЯ · ОТРЯД" or "ГОЛОС · РЯДОМ", SCP.Font("monobold", 11), x, y + r + UI.S(14),
		Color(col.r, col.g, col.b, 200 * anim), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- Значок над головой говорящего рядом
hook.Add("HUDPaint", "scp.voice.overhead", function()
	if SCP.MyState() ~= "playing" then return end
	local me = LocalPlayer()
	for ply in pairs(speaking) do
		if IsValid(ply) and ply ~= me and ply:Alive() and ply:InGame() then
			local pos = ply:GetPos() + Vector(0, 0, 84)
			local d = pos:Distance(EyePos())
			if d < 900 then
				local s = pos:ToScreen()
				if s.visible then
					local tr = util.TraceLine({ start = EyePos(), endpos = pos, filter = { me, ply }, mask = MASK_VISIBLE })
					if not tr.Hit then
						local a = math.Clamp(1 - d / 900, 0, 1) * 255
						local sz = UI.S(22) * (0.9 + 0.2 * math.min(ply:VoiceVolume() * 3, 1))
						UI.Circle(s.x, s.y, sz * 0.75, Color(0, 0, 0, a * 0.5))
						UI.DrawIcon(ply:GetNW2Bool("scp.radio") and "radio" or "mic", s.x, s.y, sz, Color(255, 255, 255, a))
					end
				end
			end
		end
	end
end)

-- Список говорящих по рации
hook.Add("HUDPaint", "scp.voice.list", function()
	if SCP.MyState() ~= "playing" then return end
	local y = ScrH() * 0.42
	local me = LocalPlayer()
	for ply in pairs(speaking) do
		if IsValid(ply) and ply ~= me and (ply:GetNW2Bool("scp.radio") or not me:Alive() or not ply:Alive()) then
			local name = ply:SCPName()
			local font = SCP.Font("semibold", 14)
			local w = UI.TextSize(name, font) + UI.S(64)
			local x = UI.S(24)
			UI.BlurRect(x, y, w, UI.S(32), 3)
			surface.SetDrawColor(10, 11, 13, 200)
			surface.DrawRect(x, y, w, UI.S(32))
			surface.SetDrawColor(UI.Col.amber)
			surface.DrawRect(x, y, UI.S(2), UI.S(32))
			UI.DrawIcon(ply:Alive() and "radio" or "skull", x + UI.S(18), y + UI.S(16), UI.S(15), UI.Col.amber)
			draw.SimpleText(name, font, x + UI.S(34), y + UI.S(16), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			-- «эквалайзер»
			local v = math.min(ply:VoiceVolume() * 3, 1)
			for i = 0, 2 do
				local hh = UI.S(4) + UI.S(12) * v * (0.5 + 0.5 * math.abs(math.sin(RealTime() * 9 + i * 1.7)))
				surface.SetDrawColor(UI.Col.amber)
				surface.DrawRect(x + w - UI.S(22) + i * UI.S(5), y + UI.S(16) - hh / 2, UI.S(3), hh)
			end
			y = y + UI.S(38)
		end
	end
end)
