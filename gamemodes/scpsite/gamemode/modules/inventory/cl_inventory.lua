--[[
	Q — «Личное дело»: слева оперативник и состояние, в центре снаряжение (ячейки, ПКМ — действия),
	справа статистика службы и текущая задача. Ходить можно не закрывая (клавиатура не перехватывается).
]]

local UI = SCP.UI
local Inv = SCP.Inv
local I = SCP.Items
local C = SCP.Config

local statRows = {
	{ "missions", "Заданий выполнено" },
	{ "missions_failed", "Заданий провалено" },
	{ "kills", "Уничтожено целей" },
	{ "deaths", "Гибелей" },
	{ "saw_096", "Видел лицо SCP-096" },
	{ "killed_by_096", "Убит SCP-096" },
	{ "killed_by_173", "Убит SCP-173" },
	{ "killed_by_049", "Убит SCP-049" },
	{ "healed", "Перевязано товарищей" },
	{ "notes", "Найдено документов" },
	{ "teamkills", "Огонь по своим" },
	{ "distance", "Пройдено", function(v) return math.Round(v) .. " м" end },
	{ "playtime", "Время на заданиях", function(v) return SCP.FormatTime(v) end },
}

local function slotMenu(slot, it)
	local def = I.Defs[it.id]
	local m = DermaMenu()
	if it.id == "note" then
		m:AddOption("Прочитать", function() I.Read(it.data and it.data.note) end):SetIcon("icon16/book_open.png")
	elseif I.Use and (it.id == "medkit" or it.id == "ammo") then
		m:AddOption("Использовать", function() I.UseSlot(slot) end):SetIcon("icon16/accept.png")
	end
	if not def.story then
		m:AddOption("Выбросить", function() I.DropSlot(slot) end):SetIcon("icon16/arrow_down.png")
	end
	m:Open()
end

function Inv.Open()
	if IsValid(Inv.Panel) then return end
	SCP.Stats.Request()
	UI.Sound("open")
	surface.PlaySound("scpsite/fx/paper.mp3")
	local root = vgui.Create("DPanel")
	Inv.Panel = root
	root:SetSize(ScrW(), ScrH())
	root:MakePopup()
	root:SetKeyboardInputEnabled(false)
	root.Born = RealTime()
	local W, H = ScrW(), ScrH()
	local pw, ph = UI.S(1440), UI.S(760)
	local px, py = W / 2 - pw / 2, H / 2 - ph / 2

	root.Paint = function(s, w, h)
		local t = UI.Ease((RealTime() - s.Born) / 0.25)
		surface.SetAlphaMultiplier(t)
		UI.BlurPanel(s, 4 * t)
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(0, 0, w, h)
		UI.Vignette(0, 0, w, h, 255)
		-- шапка
		UI.Logo(px + UI.S(24), py - UI.S(34), UI.S(40), 235)
		draw.SimpleText("ЛИЧНОЕ ДЕЛО", SCP.Font("title", 30), px + UI.S(56), py - UI.S(44), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local _, _, fac = SCP.Lobby.ModelOf(LocalPlayer())
		draw.SimpleText("ФОНД SCP · ОБЪЕКТ-19 · " .. string.upper(fac.name), SCP.Font("mono", 12), px + UI.S(57), py - UI.S(16), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("[Q] ЗАКРЫТЬ", SCP.Font("monobold", 12), px + pw, py - UI.S(30), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
	end

	local function card(x, w, title)
		local c = vgui.Create("DPanel", root)
		c:SetPos(px + x, py)
		c:SetSize(w, ph)
		c.Paint = function(s, cw, ch)
			local t = UI.Ease((RealTime() - root.Born - x / pw * 0.2) / 0.3)
			s:SetAlpha(255 * t)
			surface.SetDrawColor(9, 10, 12, 230)
			surface.DrawRect(0, 0, cw, ch)
			surface.SetDrawColor(255, 255, 255, 14)
			surface.DrawOutlinedRect(0, 0, cw, ch, 1)
			draw.SimpleText(title, SCP.Font("monobold", 12), UI.S(20), UI.S(24), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(UI.Col.red)
			surface.DrawRect(UI.S(20), UI.S(38), UI.S(22), UI.S(2))
		end
		return c
	end

	-- ----------------------------------------------------- оперативник --
	local left = card(0, UI.S(400), "ОПЕРАТИВНИК")
	local mdl = vgui.Create("DModelPanel", left)
	mdl:SetPos(0, UI.S(40))
	mdl:SetSize(left:GetWide(), UI.S(520))
	mdl:SetModel(LocalPlayer():GetModel())
	mdl:SetFOV(28)
	mdl:SetAmbientLight(Color(50, 50, 60))
	mdl:SetDirectionalLight(BOX_TOP, Color(255, 250, 240))
	mdl:SetDirectionalLight(BOX_RIGHT, Color(160, 40, 30))
	local ent = mdl:GetEntity()
	if IsValid(ent) then
		local seq = ent:LookupSequence("idle_passive")
		if seq >= 0 then ent:ResetSequence(seq) end
		ent.GetPlayerColor = function() return LocalPlayer():GetPlayerColor() end
	end
	mdl.LayoutEntity = function(s, e)
		e:SetAngles(Angle(0, 25 + math.sin(RealTime() * 0.5) * 8, 0))
		e:FrameAdvance(FrameTime())
		local c = e:OBBCenter()
		s:SetLookAt(Vector(0, 0, c.z))
		s:SetCamPos(Vector(140, 0, c.z * 1.1))
	end
	local info = vgui.Create("DPanel", left)
	info:SetPos(UI.S(20), UI.S(560))
	info:SetSize(left:GetWide() - UI.S(40), UI.S(190))
	info.Paint = function(_, w)
		local me = LocalPlayer()
		local _, idx, fac = SCP.Lobby.ModelOf(me)
		draw.SimpleText(me:SCPName(), SCP.Font("title", 26), 0, 0, UI.Col.text)
		draw.SimpleText(string.upper(fac.modelNames[idx] or "") .. " · ДОПУСК " .. (fac.clearance or 2), SCP.Font("mono", 12), 0, UI.S(36), fac.color)
		local rows = {
			{ "ЗДОРОВЬЕ", me:Health() / me:GetMaxHealth(), me:Health() < 35 and UI.Col.red or UI.Col.text, me:Health() },
			{ "БРОНЯ", me:Armor() / 100, Color(140, 170, 210), me:Armor() },
			{ "ВЫНОСЛИВОСТЬ", SCP.Stamina.Get(me) / C.Stamina.Max, Color(200, 200, 196), math.Round(SCP.Stamina.Get(me)) },
		}
		for i, r in ipairs(rows) do
			local y = UI.S(66) + (i - 1) * UI.S(40)
			draw.SimpleText(r[1], SCP.Font("monobold", 11), 0, y, UI.Col.dim)
			draw.SimpleText(r[4], SCP.Font("mono", 12), w, y, UI.Col.text, TEXT_ALIGN_RIGHT)
			surface.SetDrawColor(255, 255, 255, 20)
			surface.DrawRect(0, y + UI.S(20), w, UI.S(4))
			surface.SetDrawColor(r[3])
			surface.DrawRect(0, y + UI.S(20), w * math.Clamp(r[2], 0, 1), UI.S(4))
		end
	end

	-- ------------------------------------------------------ снаряжение --
	local mid = card(UI.S(416), UI.S(600), "СНАРЯЖЕНИЕ")
	-- оружие
	local wpn = vgui.Create("DPanel", mid)
	wpn:SetPos(UI.S(20), UI.S(56))
	wpn:SetSize(mid:GetWide() - UI.S(40), UI.S(110))
	wpn.Paint = function(_, w, h)
		surface.SetDrawColor(255, 255, 255, 7)
		surface.DrawRect(0, 0, w, h)
		local me = LocalPlayer()
		local wep = me:GetActiveWeapon()
		if not IsValid(wep) then return end
		draw.SimpleText("ОСНОВНОЕ ОРУЖИЕ", SCP.Font("monobold", 11), UI.S(16), UI.S(20), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(wep:GetPrintName(), SCP.Font("title", 26), UI.S(16), UI.S(52), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local clip, res = wep:Clip1(), me:GetAmmoCount(wep:GetPrimaryAmmoType())
		draw.SimpleText(clip .. " / " .. res, SCP.Font("mono", 14), UI.S(16), UI.S(84), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		UI.DrawIcon("crosshair", w - UI.S(52), h / 2, UI.S(52), Color(255, 255, 255, 30))
	end
	local grid = vgui.Create("DPanel", mid)
	local cols, size, gap = 4, UI.S(128), UI.S(10)
	grid:SetPos(UI.S(20), UI.S(186))
	grid:SetSize(cols * size + (cols - 1) * gap, 3 * size + 2 * gap)
	grid.Paint = function() end
	for s = 1, I.Slots do
		local b = vgui.Create("DButton", grid)
		b:SetText("")
		b:SetSize(size, size)
		b:SetPos(((s - 1) % cols) * (size + gap), math.floor((s - 1) / cols) * (size + gap))
		b.hover = 0
		b.Paint = function(self, w, h)
			local it = I.Mine[s]
			self.hover = UI.Approach(self.hover, (self:IsHovered() and it) and 1 or 0, 14)
			surface.SetDrawColor(255, 255, 255, 6 + 12 * self.hover)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255, 18 + 60 * self.hover)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			if not it then return true end
			local def = I.Defs[it.id] or {}
			local col = def.story and UI.Col.amber or UI.Col.text
			UI.DrawIcon(def.icon or "item", w / 2, h / 2 - UI.S(10), UI.S(40), col)
			local name = I.Name(it.id, it.data)
			local lines = UI.Wrap(name, SCP.Font("medium", 12), w - UI.S(12))
			draw.SimpleText(lines[1] or "", SCP.Font("medium", 12), w / 2, h - UI.S(18), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if it.n > 1 then draw.SimpleText("×" .. it.n, SCP.Font("monobold", 13), w - UI.S(8), UI.S(8), UI.Col.text, TEXT_ALIGN_RIGHT) end
			if def.story then draw.SimpleText("СЮЖЕТ", SCP.Font("monobold", 9), UI.S(8), UI.S(8), UI.Col.amber) end
			return true
		end
		b.OnCursorEntered = function(self)
			local it = I.Mine[s]
			if it then UI.Sound("hover") self:SetTooltip(I.Name(it.id, it.data) .. "\n" .. (I.Defs[it.id].desc or "")) else self:SetTooltip(false) end
		end
		b.DoClick = function()
			local it = I.Mine[s]
			if not it then return end
			UI.Sound("click")
			if it.id == "note" then I.Read(it.data and it.data.note) else slotMenu(s, it) end
		end
		b.DoRightClick = function() local it = I.Mine[s] if it then slotMenu(s, it) end end
	end
	local hint = vgui.Create("DLabel", mid)
	hint:SetPos(UI.S(20), mid:GetTall() - UI.S(40))
	hint:SetSize(mid:GetWide() - UI.S(40), UI.S(20))
	hint:SetFont(SCP.Font("mono", 11))
	hint:SetTextColor(UI.Col.faint)
	hint:SetText("ЛКМ / ПКМ — ДЕЙСТВИЯ · Z — КОМАНДЫ · G — ФОНД · B — РАЦИЯ")

	-- ----------------------------------------------------- статистика --
	local right = card(UI.S(1032), UI.S(408), "СЛУЖБА")
	local task = vgui.Create("DPanel", right)
	task:SetPos(UI.S(20), UI.S(56))
	task:SetSize(right:GetWide() - UI.S(40), UI.S(96))
	task.Paint = function(_, w, h)
		surface.SetDrawColor(255, 255, 255, 7)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(UI.Col.amber)
		surface.DrawRect(0, 0, UI.S(2), h)
		local S = SCP.Story
		local st = S.Current()
		draw.SimpleText("ТЕКУЩАЯ ЗАДАЧА", SCP.Font("monobold", 11), UI.S(16), UI.S(20), UI.Col.amber, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(st and st.title or "—", SCP.Font("titlemed", 20), UI.S(16), UI.S(48), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(st and st.goal or "Ожидание", SCP.Font("regular", 13), UI.S(16), UI.S(74), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	local stats = vgui.Create("DPanel", right)
	stats:SetPos(UI.S(20), UI.S(172))
	stats:SetSize(right:GetWide() - UI.S(40), ph - UI.S(190))
	stats.Paint = function(_, w)
		local mine = SCP.Stats.Mine or {}
		for i, r in ipairs(statRows) do
			local y = (i - 1) * UI.S(38)
			local v = mine[r[1]] or 0
			draw.SimpleText(r[2], SCP.Font("regular", 14), 0, y + UI.S(14), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(r[3] and r[3](v) or tostring(math.Round(v)), SCP.Font("titlemed", 18), w, y + UI.S(14), UI.Col.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(255, 255, 255, 10)
			surface.DrawRect(0, y + UI.S(31), w, 1)
		end
	end
end

function Inv.Close()
	if IsValid(Inv.Panel) then
		Inv.Panel:Remove()
		UI.Sound("close")
	end
end

function Inv.Toggle()
	if IsValid(Inv.Panel) then Inv.Close() else Inv.Open() end
end

hook.Add("Think", "scp.inv.autoclose", function()
	if not IsValid(Inv.Panel) then return end
	local me = LocalPlayer()
	if SCP.MyState() ~= "playing" or not me:Alive() then Inv.Close() return end
	if gui.IsGameUIVisible() then Inv.Close() gui.HideGameUI() end
end)
