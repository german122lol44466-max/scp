--[[
	Фразы на клиенте: облачко над головой (3 с) и строка в чате; круговое меню быстрых команд (Z).
]]

local UI = SCP.UI
local PH = SCP.Phrases
local bubbles = {}

net.Receive("scp.phrase", function()
	local ply, text = net.ReadEntity(), net.ReadString()
	if not IsValid(ply) then return end
	bubbles[ply] = { text = text, born = RealTime() }
	if SCP.Chat.Add then SCP.Chat.Add({ kind = "say", name = ply:SCPName(), text = text, ply = ply }) end
end)

-- «Увидел лицо» — удар по экрану: вспышка, толчок камеры, звон
local sawAt = 0
hook.Add("SCP.Saw096", "scp.phrases", function()
	sawAt = RealTime()
	SCP.Camera.Punch(Angle(-4, 0, 6))
	surface.PlaySound("scpsite/fx/horror" .. math.random(1, 4) .. ".mp3")
end)

hook.Add("HUDPaint", "scp.phrases.saw", function()
	local t = RealTime() - sawAt
	if t > 2.5 then return end
	local a = math.Clamp(1 - t / 2.5, 0, 1)
	surface.SetDrawColor(255, 255, 255, 120 * a * a)
	surface.DrawRect(0, 0, ScrW(), ScrH())
	SCP.UI.Vignette(0, 0, ScrW(), ScrH(), 255 * a)
end)

hook.Add("HUDPaint", "scp.phrases.bubbles", function()
	if SCP.MyState() ~= "playing" then return end
	local me = LocalPlayer()
	local font = SCP.Font("semibold", 15)
	for ply, b in pairs(bubbles) do
		local t = RealTime() - b.born
		if not IsValid(ply) or t > 3.5 then bubbles[ply] = nil
		elseif ply ~= me and ply:Alive() then
			local pos = ply:GetPos() + Vector(0, 0, 90)
			local d = pos:Distance(EyePos())
			local s = pos:ToScreen()
			if s.visible and d < PH.Range then
				local a = math.min(t / 0.2, 1) * math.min((3.5 - t) / 0.4, 1) * math.Clamp(1.2 - d / PH.Range, 0, 1)
				local tw = UI.TextSize(b.text, font)
				local w, h = tw + UI.S(24), UI.S(30)
				local y = s.y - h - (1 - math.min(t / 0.2, 1)) * -UI.S(10)
				surface.SetAlphaMultiplier(a)
				surface.SetDrawColor(10, 11, 13, 215)
				surface.DrawRect(s.x - w / 2, y, w, h)
				surface.SetDrawColor(255, 255, 255, 30)
				surface.DrawOutlinedRect(s.x - w / 2, y, w, h, 1)
				draw.NoTexture()
				surface.SetDrawColor(10, 11, 13, 215)
				surface.DrawPoly({ { x = s.x - UI.S(6), y = y + h }, { x = s.x + UI.S(6), y = y + h }, { x = s.x, y = y + h + UI.S(7) } })
				draw.SimpleText(b.text, font, s.x, y + h / 2, UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				surface.SetAlphaMultiplier(1)
			end
		end
	end
end)

-- ---------------------------------------------------------- круговое меню --
local wheel = { open = false, anim = 0, sel = nil }
local quickKey = CreateClientConVar("scp_phrase_key", tostring(KEY_Z), true, false, "Клавиша быстрых команд (код KEY_*)")

hook.Add("PlayerButtonDown", "scp.phrases.wheel", function(ply, key)
	if key ~= quickKey:GetInt() or not IsFirstTimePredicted() then return end
	if SCP.MyState() ~= "playing" or not ply:Alive() or vgui.GetKeyboardFocus() or gui.IsGameUIVisible() then return end
	wheel.open = true
	wheel.sel = nil
	gui.EnableScreenClicker(true)
	input.SetCursorPos(ScrW() / 2, ScrH() / 2)
	UI.Sound("open")
end)

hook.Add("PlayerButtonUp", "scp.phrases.wheel", function(ply, key)
	if key ~= quickKey:GetInt() or not IsFirstTimePredicted() or not wheel.open then return end
	wheel.open = false
	gui.EnableScreenClicker(false)
	if wheel.sel then
		net.Start("scp.phrase.req")
		net.WriteUInt(wheel.sel, 4)
		net.SendToServer()
		UI.Sound("click")
	end
end)

hook.Add("HUDPaint", "scp.phrases.wheel", function()
	wheel.anim = UI.Approach(wheel.anim, wheel.open and 1 or 0, 14)
	if wheel.anim < 0.01 then return end
	local cx, cy = ScrW() / 2, ScrH() / 2
	local a = wheel.anim
	local n = #PH.Quick
	local R = UI.S(190) * (0.85 + 0.15 * a)
	surface.SetAlphaMultiplier(a)
	UI.Circle(cx, cy, R + UI.S(80), Color(0, 0, 0, 120))
	-- выбор по направлению мыши
	if wheel.open then
		local mx, my = gui.MousePos()
		local dx, dy = mx - cx, my - cy
		if dx * dx + dy * dy > UI.S(40) ^ 2 then
			local ang = math.deg(math.atan2(dy, dx)) + 90
			wheel.sel = math.floor(((ang + 360 / n / 2) % 360) / (360 / n)) + 1
		else
			wheel.sel = nil
		end
	end
	for i, q in ipairs(PH.Quick) do
		local ang = math.rad((i - 1) * 360 / n - 90)
		local x, y = cx + math.cos(ang) * R, cy + math.sin(ang) * R
		local on = wheel.sel == i
		local w, h = UI.S(170), UI.S(54)
		surface.SetDrawColor(on and 232 or 12, on and 230 or 13, on and 224 or 16, on and 240 or 220)
		surface.DrawRect(x - w / 2, y - h / 2, w, h)
		surface.SetDrawColor(255, 255, 255, on and 0 or 30)
		surface.DrawOutlinedRect(x - w / 2, y - h / 2, w, h, 1)
		local col = on and Color(12, 12, 14) or UI.Col.text
		UI.DrawIcon(q.icon, x - w / 2 + UI.S(24), y, UI.S(18), col)
		draw.SimpleText(q.text, SCP.Font("semibold", 15), x - w / 2 + UI.S(44), y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	draw.SimpleText("КОМАНДЫ", SCP.Font("monobold", 13), cx, cy, UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	surface.SetAlphaMultiplier(1)
end)
