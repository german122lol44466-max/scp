--[[
	Круговое меню по зажатой клавише: SCP.Radial(id, { key = KEY_*, convar = "...", title = "...",
	items = function() return { {text, icon, sub}, … } end, pick = function(i) end }).
	Отпустили клавишу — выбран пункт под мышью.
]]

local UI = SCP.UI
local wheels = {}

function SCP.Radial(id, def)
	local w = { def = def, open = false, anim = 0, sel = nil, items = {} }
	wheels[id] = w
	local cv = CreateClientConVar(def.convar, tostring(def.key), true, false, def.title .. " (код KEY_*)")

	hook.Add("PlayerButtonDown", "scp.radial." .. id, function(ply, key)
		if key ~= cv:GetInt() or not IsFirstTimePredicted() then return end
		if SCP.MyState() ~= "playing" or not ply:Alive() or vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or vgui.CursorVisible() then return end
		for oid, o in pairs(wheels) do if o.open and oid ~= id then return end end
		w.open = true
		w.sel = nil
		w.items = def.items()
		gui.EnableScreenClicker(true)
		input.SetCursorPos(ScrW() / 2, ScrH() / 2)
		UI.Sound("open")
	end)

	hook.Add("PlayerButtonUp", "scp.radial." .. id, function(ply, key)
		if key ~= cv:GetInt() or not IsFirstTimePredicted() or not w.open then return end
		w.open = false
		gui.EnableScreenClicker(false)
		if w.sel then
			def.pick(w.sel, w.items[w.sel])
			UI.Sound("click")
		end
	end)

	hook.Add("HUDPaint", "scp.radial." .. id, function()
		w.anim = UI.Approach(w.anim, w.open and 1 or 0, 14)
		if w.anim < 0.01 then return end
		if w.open and (SCP.MyState() ~= "playing" or not LocalPlayer():Alive()) then
			w.open = false
			gui.EnableScreenClicker(false)
		end
		local cx, cy = ScrW() / 2, ScrH() / 2
		local a = w.anim
		local n = #w.items
		if n == 0 then return end
		local R = UI.S(n > 8 and 230 or 200) * (0.85 + 0.15 * a)
		surface.SetAlphaMultiplier(a)
		UI.Glow(cx, cy, (R + UI.S(160)) * 2, (R + UI.S(160)) * 2, Color(0, 0, 0, 230))
		UI.Ring(cx, cy, UI.S(54), Color(255, 255, 255, 30))
		if w.open then
			local mx, my = gui.MousePos()
			local dx, dy = mx - cx, my - cy
			if dx * dx + dy * dy > UI.S(44) ^ 2 then
				local ang = math.deg(math.atan2(dy, dx)) + 90
				w.sel = math.floor(((ang + 360 / n / 2) % 360) / (360 / n)) + 1
			else
				w.sel = nil
			end
		end
		-- стрелка-указатель к выбранному
		if w.sel then
			local ang = math.rad((w.sel - 1) * 360 / n - 90)
			UI.Circle(cx + math.cos(ang) * UI.S(54), cy + math.sin(ang) * UI.S(54), UI.S(5), UI.Col.red)
		end
		for i, it in ipairs(w.items) do
			local ang = math.rad((i - 1) * 360 / n - 90)
			local x, y = cx + math.cos(ang) * R, cy + math.sin(ang) * R
			local on = w.sel == i
			local bw, bh = UI.S(196), UI.S(it.sub and 62 or 52)
			local grow = on and 1.06 or 1
			bw, bh = bw * grow, bh * grow
			surface.SetDrawColor(on and 232 or 10, on and 230 or 11, on and 224 or 14, on and 245 or 225)
			surface.DrawRect(x - bw / 2, y - bh / 2, bw, bh)
			surface.SetDrawColor(255, 255, 255, on and 0 or 26)
			surface.DrawOutlinedRect(x - bw / 2, y - bh / 2, bw, bh, 1)
			if not on then
				surface.SetDrawColor(UI.Col.red)
				surface.DrawRect(x - bw / 2, y - bh / 2, UI.S(2), bh)
			end
			local col = on and Color(12, 12, 14) or UI.Col.text
			if it.icon then UI.DrawIcon(it.icon, x - bw / 2 + UI.S(24), y, UI.S(18), col) end
			local tx = x - bw / 2 + UI.S(it.icon and 44 or 14)
			draw.SimpleText(it.text, SCP.Font("semibold", 15), tx, y - (it.sub and UI.S(9) or 0), col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if it.sub then
				draw.SimpleText(it.sub, SCP.Font("mono", 10), tx, y + UI.S(12), on and Color(60, 60, 64) or UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
		draw.SimpleText(def.title, SCP.Font("monobold", 13), cx, cy, UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
	end)
	return w
end
