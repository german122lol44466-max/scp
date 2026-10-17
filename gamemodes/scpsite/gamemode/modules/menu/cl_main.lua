--[[
	Главный экран: эмблема Фонда над кнопками (слева по центру), полоса обновлений сверху,
	терминальная строка, онлайн и ваш профиль снизу.
]]

local UI = SCP.UI
local M = SCP.Menu

local ticker = {
	"ТЕРМИНАЛ ФОНДА SCP // ОБЪЕКТ-19 // СОЕДИНЕНИЕ УСТАНОВЛЕНО",
	"СТАТУС ОБЪЕКТА: НОРМАЛЬНЫЙ // СОДЕРЖАНИЕ: 1 274 ЕД.",
	"ПЕРЕСМЕНКА СЛУЖБЫ БЕЗОПАСНОСТИ: 06:00 // СЕКТОР 4-ГАММА",
	"НАПОМИНАНИЕ: ЗАПРЕЩЕНО СМОТРЕТЬ НА ИЗОБРАЖЕНИЯ SCP-096",
}

-- ---------------------------------------------------- карточка обновления --
local function openUpdate(u)
	local _, body = SCP.Modal(u.title, 760, 560, "info")
	local img = vgui.Create("DPanel", body)
	img:Dock(TOP)
	img:SetTall(UI.S(170))
	img.Paint = function(_, w, h)
		surface.SetMaterial(UI.Mat("scpsite/updates/" .. u.image .. ".png"))
		surface.SetDrawColor(255, 255, 255, 200)
		local mw = w
		local mh = mw * 0.5
		surface.DrawTexturedRectUV(0, 0, w, h, 0, 0.5 - h / mh / 2, 1, 0.5 + h / mh / 2)
		surface.SetMaterial(UI.Mat("scpsite/ui/fade_v.png"))
		surface.SetDrawColor(11, 12, 14, 255)
		surface.DrawTexturedRect(0, h * 0.3, w, h * 0.7)
		draw.SimpleText(u.tag .. "  ·  v" .. u.version .. "  ·  " .. u.date, SCP.Font("mono", 14), UI.S(14), h - UI.S(18), UI.Col.dim)
	end
	local scroll = vgui.Create("SCP.Scroll", body)
	scroll:Dock(FILL)
	scroll:DockMargin(0, UI.S(14), 0, 0)
	for _, line in ipairs(u.text) do
		local p = scroll:Add("DPanel")
		p:Dock(TOP)
		p:DockMargin(0, 0, 0, UI.S(8))
		local font = SCP.Font("regular", 17)
		local lines
		p.PerformLayout = function(s, w)
			lines = UI.Wrap(line, font, w - UI.S(30))
			s:SetTall(#lines * UI.S(24) + UI.S(4))
		end
		p.Paint = function(_, w, h)
			surface.SetDrawColor(UI.Col.red)
			surface.DrawRect(UI.S(4), UI.S(10), UI.S(6), UI.S(2))
			for i, l in ipairs(lines or {}) do
				draw.SimpleText(l, font, UI.S(24), (i - 1) * UI.S(24), UI.Col.text)
			end
		end
	end
end

local function updateCard(parent, u, i)
	local c = vgui.Create("DButton", parent)
	c:SetText("")
	c.hover = 0
	c.Born = RealTime() + 0.15 + i * 0.08
	c.OnCursorEntered = function() UI.Sound("hover") end
	c.DoClick = function() UI.Sound("open") openUpdate(u) end
	c.Paint = function(s, w, h)
		local t = UI.Ease((RealTime() - s.Born) / 0.4)
		s.hover = UI.Approach(s.hover, s:IsHovered() and 1 or 0, 12)
		surface.SetAlphaMultiplier(t)
		local y = (1 - t) * -UI.S(16)
		surface.SetDrawColor(10, 11, 13, 200 + 30 * s.hover)
		surface.DrawRect(0, y, w, h)
		-- картинка слева
		local iw = h
		surface.SetMaterial(UI.Mat("scpsite/updates/" .. u.image .. ".png"))
		surface.SetDrawColor(255, 255, 255, 150 + 100 * s.hover)
		surface.DrawTexturedRectUV(0, y, iw, h, 0.25, 0, 0.75, 1)
		surface.SetDrawColor(255, 255, 255, 20 + 70 * s.hover)
		surface.DrawOutlinedRect(0, y, w, h, 1)
		surface.SetDrawColor(UI.Col.red.r, UI.Col.red.g, UI.Col.red.b, 255)
		surface.DrawRect(iw, y, UI.S(2), h)
		draw.SimpleText(u.tag, SCP.Font("monobold", 11), iw + UI.S(14), y + UI.S(18), UI.Col.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(u.title, SCP.Font("titlemed", 19), iw + UI.S(14), y + h / 2 + UI.S(1), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("v" .. u.version .. " · " .. u.date, SCP.Font("mono", 11), iw + UI.S(14), y + h - UI.S(16), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		UI.DrawIcon("chevron_right", w - UI.S(18) + s.hover * UI.S(4), y + h / 2, UI.S(16), UI.Alpha(UI.Col.text, 80 + 175 * s.hover))
		surface.SetAlphaMultiplier(1)
		return true
	end
	return c
end

-- ------------------------------------------------------------- экран --
function M.BuildMain()
	local root = vgui.Create("DPanel")
	root:SetSize(ScrW(), ScrH())
	root:MakePopup()
	root:SetKeyboardInputEnabled(false)
	root.Born = RealTime()
	local W, H = ScrW(), ScrH()
	local colX = UI.S(120)

	root.Paint = function(s, w, h)
		local t = RealTime() - s.Born
		M.PaintBackdrop(w, h)

		-- эмблема и надпись над кнопками
		local a = UI.Ease(t / 0.8)
		local cy = h * 0.5 - UI.S(170)
		local pulse = 0.92 + math.sin(RealTime() * 1.3) * 0.08
		UI.Logo(colX + UI.S(56), cy - UI.S(60), UI.S(112), 255 * a, true)
		surface.SetAlphaMultiplier(a)
		draw.SimpleText("SCP", SCP.Font("title", 82), colX + UI.S(132), cy - UI.S(84), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("ОБЪЕКТ-19", SCP.Font("titlelight", 30), colX + UI.S(136), cy - UI.S(28), UI.Alpha(UI.Col.text, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("ОБЕЗОПАСИТЬ · УДЕРЖАТЬ · СОХРАНИТЬ", SCP.Font("mono", 13), colX + UI.S(2), cy + UI.S(22),
			UI.Alpha(UI.Col.dim, 220 * pulse), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(255, 255, 255, 30)
		surface.DrawRect(colX, cy + UI.S(42), UI.S(360), 1)
		surface.SetDrawColor(UI.Col.red)
		surface.DrawRect(colX, cy + UI.S(42), UI.S(36), 1)

		-- терминальная строка
		local line = ticker[math.floor(RealTime() / 6) % #ticker + 1]
		local chars = math.min(utf8.len(line), math.floor((RealTime() % 6) * 40))
		local shown = string.sub(line, 1, (utf8.offset(line, chars + 1) or (#line + 1)) - 1)
		draw.SimpleText("> " .. shown .. M.Cursor(), SCP.Font("mono", 13), colX, h - UI.S(92), UI.Alpha(UI.Col.text, 150))

		-- низ: версия и онлайн
		draw.SimpleText("v" .. SCP.Version .. "  ·  " .. GetHostName() .. "  ·  онлайн " .. player.GetCount() .. "/" .. game.MaxPlayers(),
			SCP.Font("mono", 12), colX, h - UI.S(56), UI.Col.faint)

		-- полоса обновлений
		draw.SimpleText("ОБНОВЛЕНИЯ", SCP.Font("monobold", 12), colX, UI.S(46), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(UI.Col.red)
		surface.DrawRect(colX, UI.S(58), UI.S(20), 1)
		surface.SetAlphaMultiplier(1)
	end

	-- кнопки
	local btns = {
		{ "ИГРАТЬ", "СЮЖЕТНАЯ КАМПАНИЯ · ГЛАВА I", function() M.Go("select") end },
		{ "ОТКЛЮЧИТЬСЯ", "ПОКИНУТЬ СЕРВЕР", function()
			local _, body = SCP.Modal("Отключиться?", 460, 220, "logout")
			local txt = vgui.Create("DLabel", body)
			txt:Dock(TOP)
			txt:SetFont(SCP.Font("regular", 16))
			txt:SetTextColor(UI.Col.dim)
			txt:SetText("Вы покинете сервер.")
			txt:SizeToContents()
			local row = vgui.Create("DPanel", body)
			row:Dock(BOTTOM)
			row:SetTall(UI.S(44))
			row.Paint = function() end
			local yes = vgui.Create("SCP.Button", row)
			yes:Dock(RIGHT)
			yes:SetWide(UI.S(180))
			yes:SetLabel("Отключиться")
			yes:SetDanger(true)
			yes:SetPrimary(true)
			yes.DoClick = function() RunConsoleCommand("disconnect") end
		end },
	}
	local y = H * 0.5 - UI.S(70)
	for i, d in ipairs(btns) do
		local b = vgui.Create("SCP.MenuButton", root)
		b:SetPos(colX - UI.S(18), y)
		b:SetSize(UI.S(440), UI.S(76))
		b:SetLabel(d[1], d[2])
		b.Delay = 0.25 + i * 0.1
		b.DoClick = d[3]
		y = y + UI.S(84)
	end

	-- обновления сверху
	local x = colX + UI.S(130)
	for i, u in ipairs(M.Updates or {}) do
		if i > 4 then break end
		local c = updateCard(root, u, i)
		c:SetPos(x, UI.S(22))
		c:SetSize(UI.S(330), UI.S(76))
		x = x + UI.S(342)
	end

	-- профиль справа снизу
	local prof = vgui.Create("DPanel", root)
	prof:SetSize(UI.S(320), UI.S(56))
	prof:SetPos(W - UI.S(320) - UI.S(48), H - UI.S(56) - UI.S(40))
	prof.Paint = function(_, w, h)
		local me = LocalPlayer()
		draw.SimpleText(me:SCPName(), SCP.Font("semibold", 17), w - UI.S(70), UI.S(18), UI.Col.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		draw.SimpleText("СЛУЖБА БЕЗОПАСНОСТИ · ДОПУСК 2", SCP.Font("mono", 11), w - UI.S(70), UI.S(40), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(255, 255, 255, 40)
		surface.DrawOutlinedRect(w - UI.S(56), 0, UI.S(56), UI.S(56), 1)
	end
	local av = vgui.Create("AvatarImage", prof)
	av:SetSize(UI.S(52), UI.S(52))
	av:SetPos(prof:GetWide() - UI.S(54), UI.S(2))
	av:SetPlayer(LocalPlayer(), 64)

	return root
end
