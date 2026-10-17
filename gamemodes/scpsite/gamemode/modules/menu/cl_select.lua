--[[
	Выбор режима: две панели — одиночная игра и мультиплеер.
]]

local UI = SCP.UI
local M = SCP.Menu

local soloChapter = 1

local function startSolo()
	net.Start("scp.menu.solo")
	net.WriteUInt(soloChapter, 4)
	net.SendToServer()
	M.CloseAll()
end

local function confirmSolo()
	local others = player.GetCount() - 1
	local kick = GetConVar("scp_solo_kick") and GetConVar("scp_solo_kick"):GetBool()
	if others <= 0 or not kick then
		startSolo()
		return
	end
	local bg, body = SCP.Modal("Одиночная игра", 520, 250, "user")
	local txt = vgui.Create("DLabel", body)
	txt:Dock(TOP)
	txt:SetWrap(true)
	txt:SetAutoStretchVertical(true)
	txt:SetFont(SCP.Font("regular", 16))
	txt:SetTextColor(UI.Col.dim)
	txt:SetText("На сервере ещё " .. others .. " игрок(ов). В одиночной игре все они будут отключены от сервера.")
	local row = vgui.Create("DPanel", body)
	row:Dock(BOTTOM)
	row:SetTall(UI.S(44))
	row.Paint = function() end
	local yes = vgui.Create("SCP.Button", row)
	yes:Dock(RIGHT)
	yes:SetWide(UI.S(220))
	yes:SetPrimary(true)
	yes:SetLabel("Начать одному")
	yes.DoClick = function()
		bg:Remove()
		startSolo()
	end
end

-- Одиночная игра: сначала выбор главы
local function pickChapter()
	local bg, body, f = SCP.Modal("Одиночная игра — выбор главы", 760, 640, "user")
	local ch = SCP.Story.Chapters
	soloChapter = math.Clamp(soloChapter, 1, #ch)
	local desc = vgui.Create("DPanel", body)
	desc:SetPos(UI.S(360), 0)
	desc:SetSize(body:GetWide() - UI.S(360), body:GetTall() - UI.S(60))
	desc.Paint = function(_, w)
		local c = ch[soloChapter]
		local fac = SCP.Config.Factions[c.faction]
		draw.SimpleText("ГЛАВА " .. c.roman, SCP.Font("monobold", 12), 0, UI.S(10), UI.Col.red)
		draw.SimpleText(c.title, SCP.Font("title", 34), 0, UI.S(28), UI.Col.text)
		draw.SimpleText(string.upper(fac.name), SCP.Font("mono", 11), 0, UI.S(76), fac.color)
		for li, l in ipairs(UI.Wrap(c.desc, SCP.Font("regular", 15), w)) do
			draw.SimpleText(l, SCP.Font("regular", 15), 0, UI.S(104) + (li - 1) * UI.S(22), UI.Col.dim)
		end
		for k, st in ipairs(c.stages) do
			draw.SimpleText(k .. ". " .. st.title, SCP.Font("medium", 14), 0, UI.S(220) + (k - 1) * UI.S(26), UI.Col.text)
		end
	end
	M.ChapterList(body, 0, -UI.S(10), UI.S(330), function() return soloChapter end, function(i) soloChapter = i end)
	local go = vgui.Create("SCP.Button", body)
	go:SetSize(UI.S(260), UI.S(48))
	go:SetPos(body:GetWide() - UI.S(260), body:GetTall() - UI.S(48))
	go:SetPrimary(true)
	go:SetFontStyle("title", 20)
	go:SetLabel("НАЧАТЬ")
	go:SetIcon("play")
	go.DoClick = function() bg:Remove() confirmSolo() end
end

local function card(parent, d, i)
	local c = vgui.Create("DButton", parent)
	c:SetText("")
	c.hover = 0
	c.Born = RealTime() + 0.2 + i * 0.12
	c.OnCursorEntered = function() UI.Sound("hover") end
	c.DoClick = function() UI.Sound("start") d.click() end
	c.Paint = function(s, w, h)
		local t = UI.Ease((RealTime() - s.Born) / 0.5)
		s.hover = UI.Approach(s.hover, s:IsHovered() and 1 or 0, 10)
		local hv = s.hover
		surface.SetAlphaMultiplier(t)
		local lift = (1 - t) * UI.S(40) - hv * UI.S(8)

		-- картинка (лёгкий зум при наведении)
		local zoom = 0.06 * (1 - hv)
		surface.SetMaterial(UI.Mat("scpsite/updates/" .. d.image .. ".png"))
		surface.SetDrawColor(255, 255, 255, 120 + 110 * hv)
		surface.DrawTexturedRectUV(0, lift, w, h * 0.62, 0.18 + zoom, zoom, 0.82 - zoom, 1 - zoom)
		surface.SetMaterial(UI.Mat("scpsite/ui/fade_v.png"))
		surface.SetDrawColor(9, 10, 12, 255)
		surface.DrawTexturedRect(0, lift + h * 0.2, w, h * 0.43)
		surface.SetDrawColor(9, 10, 12, 245)
		surface.DrawRect(0, lift + h * 0.62, w, h * 0.38)
		UI.Scanlines(0, lift, w, h * 0.62, 30)

		surface.SetDrawColor(255, 255, 255, 25 + 90 * hv)
		surface.DrawOutlinedRect(0, lift, w, h, 1)
		UI.Corners(-UI.S(6), lift - UI.S(6), w + UI.S(12), h + UI.S(12), UI.S(18), Color(255, 255, 255, 140 * hv), 2)

		local x = UI.S(30)
		UI.DrawIcon(d.icon, x + UI.S(14), lift + h * 0.62 - UI.S(4), UI.S(28), UI.Col.text)
		draw.SimpleText(d.tag, SCP.Font("monobold", 12), x, lift + h * 0.62 + UI.S(32), UI.Col.red)
		draw.SimpleText(d.title, SCP.Font("title", 38), x, lift + h * 0.62 + UI.S(50), UI.Col.text)
		local lines = UI.Wrap(d.desc, SCP.Font("regular", 15), w - x * 2)
		for li, l in ipairs(lines) do
			draw.SimpleText(l, SCP.Font("regular", 15), x, lift + h * 0.62 + UI.S(104) + (li - 1) * UI.S(21), UI.Col.dim)
		end
		draw.SimpleText("ВЫБРАТЬ", SCP.Font("monobold", 13), w - x - UI.S(26) - hv * UI.S(6), lift + h - UI.S(32), UI.Alpha(UI.Col.text, 120 + 135 * hv), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		UI.DrawIcon("arrow_right", w - x - UI.S(8) + hv * UI.S(4), lift + h - UI.S(32), UI.S(18), UI.Alpha(UI.Col.text, 120 + 135 * hv))
		surface.SetAlphaMultiplier(1)
		return true
	end
	return c
end

function M.BuildSelect()
	local root = vgui.Create("DPanel")
	root:SetSize(ScrW(), ScrH())
	root:MakePopup()
	root:SetKeyboardInputEnabled(false)
	root.Born = RealTime()
	root.Paint = function(s, w, h)
		M.PaintBackdrop(w, h, 160)
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawRect(0, 0, w, h)
		local a = UI.Ease((RealTime() - s.Born) / 0.5)
		surface.SetAlphaMultiplier(a)
		UI.Logo(w / 2, UI.S(96), UI.S(52), 230)
		draw.SimpleText("ВЫБЕРИТЕ РЕЖИМ", SCP.Font("title", 34), w / 2, UI.S(160), UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("СЮЖЕТНАЯ КАМПАНИЯ · " .. #SCP.Story.Chapters .. " ГЛАВ · ОХРАНА И МОГ ЭПСИЛОН-11", SCP.Font("mono", 13), w / 2, UI.S(194), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
	end

	local cw, ch, gap = UI.S(470), UI.S(560), UI.S(48)
	local x0 = ScrW() / 2 - cw - gap / 2
	local y0 = ScrH() / 2 - ch / 2 + UI.S(50)
	local defs = {
		{ tag = "ОДИН ОПЕРАТИВНИК", title = "ОДИНОЧНАЯ ИГРА", icon = "user", image = "096",
			desc = "Сюжет в одиночку. Тишина, пустые коридоры и он. Остальные игроки будут отключены от сервера.",
			click = pickChapter },
		{ tag = "ОТРЯД ДО " .. SCP.Config.LobbyMax .. " ЧЕЛОВЕК", title = "МУЛЬТИПЛЕЕР", icon = "users", image = "mtf",
			desc = "Соберите отряд: выберите оперативника, пригласите игроков с сервера и общайтесь голосом прямо в лобби.",
			click = function() net.Start("scp.menu.multi") net.SendToServer() end },
	}
	for i, d in ipairs(defs) do
		local c = card(root, d, i)
		c:SetPos(x0 + (i - 1) * (cw + gap), y0)
		c:SetSize(cw, ch)
	end

	local back = vgui.Create("SCP.Button", root)
	back:SetSize(UI.S(170), UI.S(46))
	back:SetPos(UI.S(48), ScrH() - UI.S(46) - UI.S(40))
	back:SetLabel("НАЗАД")
	back:SetIcon("arrow_left")
	back.DoClick = function() M.Go("main") end
	return root
end
