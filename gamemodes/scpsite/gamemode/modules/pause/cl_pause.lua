--[[
	Своё меню паузы (ESC) вместо стандартного: продолжить, настройки, покинуть задание/отряд,
	отключиться, меню Garry's Mod (консоль, настройки игры). Справа — сводка задания и отряд.
	Если открыто поле ввода (чат и т.п.) — ESC сначала закрывает его.
]]

local UI = SCP.UI
local Set = SCP.Settings
local PM = {}
SCP.Pause = PM
local allowGameUI = false

-- ----------------------------------------------------------- настройки --
function PM.Settings(parent)
	local scroll = vgui.Create("SCP.Scroll", parent)
	scroll:Dock(FILL)
	local function add(cls)
		local p = scroll:Add(cls)
		p:Dock(TOP)
		p:DockMargin(0, UI.S(4), UI.S(10), 0)
		return p
	end
	local function cvSlider(label, cv, min, max, fmt)
		local s = add("SCP.Slider")
		s:Setup(label, min, max, 2, function() return GetConVar(cv):GetFloat() end, function(v) RunConsoleCommand(cv, tostring(v)) end,
			fmt or function(v) return math.Round(v * 100) .. "%" end)
	end
	local function cvToggle(label, cv)
		local t = add("SCP.Toggle")
		t:Setup(label, function() return GetConVar(cv):GetBool() end, function(v) RunConsoleCommand(cv, v and "1" or "0") end)
	end

	SCP.Section(scroll, "Звук")
	cvSlider("Громкость голосового чата", "scp_voice_volume", 0, 2)
	cvSlider("Музыка", "scp_music", 0, 1)
	cvSlider("Оповещения объекта", "scp_vo_volume", 0, 1.5)
	cvSlider("Атмосфера комплекса", "scp_ambient_volume", 0, 1.5)
	local hint = add("DLabel")
	hint:SetFont(SCP.Font("regular", 13))
	hint:SetTextColor(UI.Col.faint)
	hint:SetText("Громкость отдельного игрока — TAB, клик по нему.")
	hint:SetTall(UI.S(22))

	SCP.Section(scroll, "Интерфейс")
	local hud = add("SCP.Choice")
	hud:Setup("Стиль HUD", { { "minimal", "Объект-19" }, { "cb", "Containment Breach" }, { "sl", "Secret Laboratory" } },
		function() return GetConVar("scp_hud_style"):GetString() end, function(v) RunConsoleCommand("scp_hud_style", v) end)
	cvToggle("Метки целей и предметов", "scp_markers")
	cvToggle("Виньетка", "scp_vignette")
	cvToggle("Зерно и цветокоррекция", "scp_grain")

	SCP.Section(scroll, "Камера")
	cvSlider("Покачивание камеры", "scp_camera_bob", 0, 1.5)
	cvToggle("Ноги от первого лица", "scp_legs")

	SCP.Section(scroll, "Управление")
	local keys = {
		{ "Q (коротко)", "Личное дело" }, { "Q / E (удерживать)", "Выглядывать влево / вправо" },
		{ "E по товарищу", "Взаимодействие" }, { "Z", "Команды отряду" }, { "G", "Реплики Фонда (МОГ)" },
		{ "B", "Рация" }, { "X", "Моргнуть (рядом SCP-173)" }, { "ALT", "Показать здоровье и патроны" },
	}
	for _, k in ipairs(keys) do
		local r = add("DPanel")
		r:SetTall(UI.S(30))
		r.Paint = function(_, w, h)
			draw.SimpleText(k[2], SCP.Font("regular", 14), 0, h / 2, UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(k[1], SCP.Font("monobold", 12), w, h / 2, UI.Col.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
	return scroll
end

-- --------------------------------------------------------------- меню --
function PM.Close()
	if IsValid(PM.Panel) then PM.Panel:Remove() end
end

local function confirm(title, text, label, fn)
	local bg, body = SCP.Modal(title, 480, 230, "warning")
	local t = vgui.Create("DLabel", body)
	t:Dock(TOP)
	t:SetWrap(true)
	t:SetAutoStretchVertical(true)
	t:SetFont(SCP.Font("regular", 15))
	t:SetTextColor(UI.Col.dim)
	t:SetText(text)
	local row = vgui.Create("DPanel", body)
	row:Dock(BOTTOM)
	row:SetTall(UI.S(44))
	row.Paint = function() end
	local yes = vgui.Create("SCP.Button", row)
	yes:Dock(RIGHT)
	yes:SetWide(UI.S(200))
	yes:SetPrimary(true)
	yes:SetDanger(true)
	yes:SetLabel(label)
	yes.DoClick = function() bg:Remove() fn() end
end

function PM.Open()
	if IsValid(PM.Panel) then return end
	UI.Sound("open")
	local root = vgui.Create("DPanel")
	PM.Panel = root
	root:SetSize(ScrW(), ScrH())
	root:MakePopup()
	root:SetKeyboardInputEnabled(false)
	root.Born = RealTime()
	local W, H = ScrW(), ScrH()
	local colX = UI.S(110)
	local st = SCP.MyState()

	root.Paint = function(s, w, h)
		local t = UI.Ease((RealTime() - s.Born) / 0.25)
		surface.SetAlphaMultiplier(t)
		UI.BlurPanel(s, 5)
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(0, 0, w, h)
		surface.SetMaterial(UI.Mat("scpsite/ui/fade_h.png"))
		surface.SetDrawColor(0, 0, 0, 230)
		surface.DrawTexturedRect(0, 0, w * 0.5, h)
		SCP.Menu.Ambient(w, h)
		UI.Vignette(0, 0, w, h, 255)
		UI.Scanlines(0, 0, w, h, 18)
		local cy = h * 0.5 - UI.S(190)
		UI.Logo(colX + UI.S(40), cy - UI.S(40), UI.S(80), 240, true)
		draw.SimpleText("ПАУЗА", SCP.Font("title", 54), colX + UI.S(98), cy - UI.S(52), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("ТЕРМИНАЛ ОПЕРАТИВНИКА" .. SCP.Menu.Cursor(), SCP.Font("mono", 12), colX + UI.S(100), cy - UI.S(14), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
	end

	local btns = { { "ПРОДОЛЖИТЬ", "ВЕРНУТЬСЯ В ИГРУ", function() PM.Close() end } }
	btns[#btns + 1] = { "НАСТРОЙКИ", "ЗВУК · ИНТЕРФЕЙС · КАМЕРА", function() PM.ShowSettings() end }
	if st == "playing" then
		btns[#btns + 1] = { "ПОКИНУТЬ ЗАДАНИЕ", "ВЕРНУТЬСЯ В ЛОББИ", function()
			confirm("Покинуть задание?", "Вы вернётесь в лобби. Снаряжение задания будет потеряно, отряд продолжит без вас.", "Покинуть", function()
				net.Start("scp.story.leave") net.SendToServer()
				PM.Close()
			end)
		end }
	elseif st == "lobby" then
		btns[#btns + 1] = { "ПОКИНУТЬ ОТРЯД", "ВЫЙТИ В ГЛАВНОЕ МЕНЮ", function()
			net.Start("scp.lobby.leave") net.SendToServer()
			PM.Close()
		end }
	end
	btns[#btns + 1] = { "ОТКЛЮЧИТЬСЯ", "ПОКИНУТЬ СЕРВЕР", function()
		confirm("Отключиться?", "Вы покинете сервер.", "Отключиться", function() RunConsoleCommand("disconnect") end)
	end }

	local y = H * 0.5 - UI.S(90)
	for i, d in ipairs(btns) do
		local b = vgui.Create("SCP.MenuButton", root)
		b:SetPos(colX - UI.S(18), y)
		b:SetSize(UI.S(440), UI.S(72))
		b:SetLabel(d[1], d[2])
		b.Index = i
		b.Delay = i * 0.05
		b.DoClick = d[3]
		y = y + UI.S(78)
	end
	local gm = vgui.Create("SCP.Button", root)
	gm:SetSize(UI.S(240), UI.S(38))
	gm:SetPos(colX, H - UI.S(38) - UI.S(44))
	gm:SetLabel("Меню Garry's Mod")
	gm:SetIcon("settings")
	gm.DoClick = function()
		PM.Close()
		allowGameUI = true
		gui.ActivateGameUI()
	end

	-- справа: сводка задания
	if st == "playing" then
		local card = vgui.Create("DPanel", root)
		card:SetSize(UI.S(460), UI.S(520))
		card:SetPos(W - UI.S(460) - UI.S(70), H / 2 - UI.S(260))
		card.Paint = function(_, w, h)
			surface.SetDrawColor(9, 10, 12, 225)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255, 16)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			local S = SCP.Story
			local ch = S.ChapterDef()
			local cur = S.Current()
			draw.SimpleText("ГЛАВА " .. ch.roman .. " · " .. string.upper(ch.title), SCP.Font("monobold", 12), UI.S(22), UI.S(28), UI.Col.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(cur and cur.title or "—", SCP.Font("title", 30), UI.S(22), UI.S(62), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(cur and cur.goal or "", SCP.Font("regular", 15), UI.S(22), UI.S(96), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			-- этапы
			for i, stg in ipairs(S.StagesOf()) do
				local yy = UI.S(136) + (i - 1) * UI.S(30)
				local done = i < S.State.stage
				local now = i == S.State.stage
				UI.Circle(UI.S(30), yy, UI.S(5), done and UI.Col.green or (now and UI.Col.amber or Color(255, 255, 255, 40)))
				draw.SimpleText(stg.title, SCP.Font(now and "semibold" or "regular", 14), UI.S(46), yy, now and UI.Col.text or UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			-- отряд
			local yy = UI.S(136) + #S.StagesOf() * UI.S(30) + UI.S(24)
			draw.SimpleText("ОТРЯД", SCP.Font("monobold", 11), UI.S(22), yy, UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			for _, p in ipairs(player.GetAll()) do
				if p:InGame() then
					yy = yy + UI.S(28)
					local hp = p:Alive() and p:Health() or 0
					draw.SimpleText(p:SCPName(), SCP.Font("medium", 14), UI.S(22), yy, p:Alive() and UI.Col.text or UI.Col.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					surface.SetDrawColor(255, 255, 255, 20)
					surface.DrawRect(w - UI.S(140), yy - UI.S(2), UI.S(118), UI.S(4))
					surface.SetDrawColor(hp < 35 and UI.Col.red or UI.Col.text)
					surface.DrawRect(w - UI.S(140), yy - UI.S(2), UI.S(118) * hp / 100, UI.S(4))
				end
			end
		end
	end
end

function PM.ShowSettings()
	local bg, body = SCP.Modal("Настройки", 620, 760, "settings")
	PM.Settings(body)
end

-- Перехват ESC: вместо стандартного меню — наше
hook.Add("PreRender", "scp.pause", function()
	if not gui.IsGameUIVisible() then allowGameUI = false return end
	if allowGameUI then return end
	if not input.IsKeyDown(KEY_ESCAPE) then return end
	gui.HideGameUI()
	-- сначала закрываем открытые окна ввода/модалки
	local focus = vgui.GetKeyboardFocus()
	if IsValid(focus) then
		local top = focus
		while IsValid(top:GetParent()) and top:GetParent() ~= vgui.GetWorldPanel() do top = top:GetParent() end
		if top.SCPCloseOnEsc then top:SCPCloseOnEsc() return end
	end
	if SCP.CloseTopModal and SCP.CloseTopModal() then return end
	if IsValid(PM.Panel) then PM.Close() return end
	if IsValid(SCP.Inv.Panel) then SCP.Inv.Close() return end
	PM.Open()
end)
