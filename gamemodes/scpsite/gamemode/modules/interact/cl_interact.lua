--[[
	E по товарищу — круговое меню действий у центра экрана; «Осмотреть» — карточка состояния.
	Полоса действия (перевязка) — снизу по центру.
]]

local UI = SCP.UI
local IA = SCP.Interact

local function inspect(t)
	local bg, body = SCP.Modal(t:SCPName(), 460, 330, "eye")
	body.Paint = function(_, w)
		if not IsValid(t) then bg:Remove() return end
		local _, idx, fac = SCP.Lobby.ModelOf(t)
		draw.SimpleText(string.upper(fac.name), SCP.Font("monobold", 11), 0, 0, fac.color)
		draw.SimpleText(fac.modelNames[idx] or "", SCP.Font("titlemed", 20), 0, UI.S(20), UI.Col.text)
		local hp = t:Health()
		local rows = {
			{ "Здоровье", hp .. "%", hp < 35 and UI.Col.red or (hp < 70 and UI.Col.amber or UI.Col.green) },
			{ "Броня", t:Armor(), UI.Col.text },
			{ "Выносливость", math.Round(SCP.Stamina.Get(t)) .. "%", UI.Col.text },
			{ "Состояние", hp < 35 and "Тяжело ранен — нужна перевязка" or (hp < 70 and "Ранен" or "В строю"), UI.Col.dim },
		}
		for i, r in ipairs(rows) do
			local y = UI.S(70) + (i - 1) * UI.S(40)
			draw.SimpleText(r[1], SCP.Font("regular", 15), 0, y, UI.Col.dim)
			draw.SimpleText(tostring(r[2]), SCP.Font("semibold", 15), w, y, r[3], TEXT_ALIGN_RIGHT)
			surface.SetDrawColor(255, 255, 255, 12)
			surface.DrawRect(0, y + UI.S(28), w, 1)
		end
	end
end

-- Меню действий: открывается по E на товарище, закрывается отпусканием E (выбор — по наведению)
local menu = { open = false, anim = 0, sel = nil, target = nil }

local function close(pick)
	if not menu.open then return end
	menu.open = false
	gui.EnableScreenClicker(false)
	if pick and menu.sel and IsValid(menu.target) then
		local a = IA.Actions[menu.sel]
		UI.Sound("click")
		if a.id == "inspect" then inspect(menu.target) return end
		net.Start("scp.interact.act")
		net.WriteEntity(menu.target)
		net.WriteString(a.id)
		net.SendToServer()
	end
end

hook.Add("PlayerBindPress", "scp.interact", function(ply, bind, pressed)
	if not string.find(bind, "+use", 1, true) or SCP.MyState() ~= "playing" or not ply:Alive() then return end
	if pressed then
		local t = IA.Target(ply)
		if t and not menu.open then
			menu.open, menu.target, menu.sel = true, t, nil
			gui.EnableScreenClicker(true)
			input.SetCursorPos(ScrW() / 2, ScrH() / 2)
			UI.Sound("open")
			return true
		end
	end
end)

hook.Add("Think", "scp.interact", function()
	if not menu.open then return end
	local key = input.GetKeyCode(input.LookupBinding("+use") or "e")
	if not input.IsKeyDown(key) and not input.IsMouseDown(MOUSE_LEFT) then close(true) end
	if input.IsMouseDown(MOUSE_LEFT) and menu.sel then close(true) end
	if not IsValid(menu.target) or not menu.target:Alive() or LocalPlayer():GetPos():DistToSqr(menu.target:GetPos()) > (IA.Range + 60) ^ 2 then close(false) end
end)

hook.Add("HUDPaint", "scp.interact", function()
	menu.anim = UI.Approach(menu.anim, menu.open and 1 or 0, 14)
	-- полоса действия (перевязка)
	local me = LocalPlayer()
	local untilT = me:GetNW2Float("scp.action", 0)
	if untilT > CurTime() then
		local frac = 1 - (untilT - CurTime()) / 3
		local w = UI.S(320)
		local x, y = ScrW() / 2 - w / 2, ScrH() / 2 + UI.S(110)
		draw.SimpleText(me:GetNW2String("scp.actionText", ""), SCP.Font("semibold", 15), ScrW() / 2, y - UI.S(14), UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(255, 255, 255, 30)
		surface.DrawRect(x, y, w, UI.S(4))
		surface.SetDrawColor(UI.Col.green)
		surface.DrawRect(x, y, w * frac, UI.S(4))
	end
	if menu.anim < 0.01 then return end
	local cx, cy = ScrW() / 2, ScrH() / 2
	local n = #IA.Actions
	local R = UI.S(150)
	surface.SetAlphaMultiplier(menu.anim)
	UI.Glow(cx, cy, R * 4, R * 4, Color(0, 0, 0, 220))
	if menu.open then
		local mx, my = gui.MousePos()
		local dx, dy = mx - cx, my - cy
		if dx * dx + dy * dy > UI.S(40) ^ 2 then
			local ang = math.deg(math.atan2(dy, dx)) + 90
			menu.sel = math.floor(((ang + 360 / n / 2) % 360) / (360 / n)) + 1
		else
			menu.sel = nil
		end
	end
	for i, a in ipairs(IA.Actions) do
		local ang = math.rad((i - 1) * 360 / n - 90)
		local x, y = cx + math.cos(ang) * R, cy + math.sin(ang) * R
		local on = menu.sel == i
		local bw, bh = UI.S(180), UI.S(56)
		surface.SetDrawColor(on and 232 or 10, on and 230 or 11, on and 224 or 14, on and 245 or 225)
		surface.DrawRect(x - bw / 2, y - bh / 2, bw, bh)
		surface.SetDrawColor(255, 255, 255, on and 0 or 26)
		surface.DrawOutlinedRect(x - bw / 2, y - bh / 2, bw, bh, 1)
		local col = on and Color(12, 12, 14) or UI.Col.text
		UI.DrawIcon(a.icon, x - bw / 2 + UI.S(22), y, UI.S(18), col)
		draw.SimpleText(a.text, SCP.Font("semibold", 14), x - bw / 2 + UI.S(40), y - UI.S(8), col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(a.sub, SCP.Font("mono", 9), x - bw / 2 + UI.S(40), y + UI.S(11), on and Color(60, 60, 64) or UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	if IsValid(menu.target) then
		draw.SimpleText(menu.target:SCPName(), SCP.Font("title", 20), cx, cy - UI.S(6), UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(menu.target:Health() .. "% · ОТПУСТИТЕ E", SCP.Font("mono", 10), cx, cy + UI.S(16), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	surface.SetAlphaMultiplier(1)
end)
