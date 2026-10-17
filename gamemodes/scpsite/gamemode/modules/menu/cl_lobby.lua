--[[
	Экран лобби: в центре модель оперативника (стрелки — выбор, имя сверху — клик для смены),
	справа — отряд и «Пригласить», снизу — «Играть». Голос отряда работает прямо здесь.
]]

local UI = SCP.UI
local M = SCP.Menu
local L = SCP.Lobby
local C = SCP.Config

local function voiceKey()
	local k = input.LookupBinding("+voicerecord")
	return k and string.upper(k) or "V"
end

-- ---------------------------------------------------------- приглашения --
local function openInvite()
	local _, body = SCP.Modal("Пригласить в отряд", 560, 620, "user_plus")
	local search = vgui.Create("SCP.Entry", body)
	search:Dock(TOP)
	search:SetTall(UI.S(38))
	search:SetPlaceholder("Поиск по имени…")
	local scroll = vgui.Create("SCP.Scroll", body)
	scroll:Dock(FILL)
	scroll:DockMargin(0, UI.S(12), 0, 0)

	local function fill()
		scroll:Clear()
		local q = string.lower(search:GetValue() or "")
		local n = 0
		for _, p in ipairs(player.GetAll()) do
			if p ~= LocalPlayer() and (q == "" or string.find(string.lower(p:SCPName() .. " " .. p:Nick()), q, 1, true)) then
				n = n + 1
				local inMine = L.Mine and p:SCPLobby() == L.Mine.id
				local busy = p:InGame()
				local row = scroll:Add("DPanel")
				row:Dock(TOP)
				row:SetTall(UI.S(58))
				row:DockMargin(0, 0, 0, UI.S(6))
				row.Paint = function(_, w, h)
					surface.SetDrawColor(255, 255, 255, 6)
					surface.DrawRect(0, 0, w, h)
					draw.SimpleText(p:SCPName(), SCP.Font("semibold", 16), UI.S(66), UI.S(19), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					local st = inMine and "в вашем отряде" or (busy and "на задании" or (p:SCPState() == "lobby" and "в другом отряде" or "в меню"))
					draw.SimpleText(p:Nick() .. " · " .. st, SCP.Font("mono", 12), UI.S(66), UI.S(40), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
				local av = vgui.Create("AvatarImage", row)
				av:SetSize(UI.S(42), UI.S(42))
				av:SetPos(UI.S(8), UI.S(8))
				av:SetPlayer(p, 64)
				local b = vgui.Create("SCP.Button", row)
				b:Dock(RIGHT)
				b:DockMargin(0, UI.S(10), UI.S(10), UI.S(10))
				b:SetWide(UI.S(150))
				b:SetLabel(inMine and "В отряде" or "Пригласить")
				b:SetIcon(inMine and "check" or "user_plus")
				b:SetEnabled(not inMine and not busy)
				b.DoClick = function()
					net.Start("scp.lobby.invite")
					net.WriteEntity(p)
					net.SendToServer()
					b:SetLabel("Отправлено")
					b:SetEnabled(false)
				end
			end
		end
		if n == 0 then
			local e = scroll:Add("DLabel")
			e:Dock(TOP)
			e:SetTall(UI.S(60))
			e:SetFont(SCP.Font("regular", 16))
			e:SetTextColor(UI.Col.faint)
			e:SetContentAlignment(5)
			e:SetText("На сервере больше никого нет")
		end
	end
	search.OnChange = fill
	fill()
end

-- ------------------------------------------------------------ смена имени --
local function editName(parent, x, y, w)
	local e = vgui.Create("SCP.Entry", parent)
	e:SetSize(w, UI.S(46))
	e:SetPos(x - w / 2, y - UI.S(23))
	e:SetFont(SCP.Font("title", 28))
	e:SetValue(LocalPlayer():SCPName())
	parent:SetKeyboardInputEnabled(true)
	e:RequestFocus()
	e:SelectAllText()
	local function done(save)
		if not IsValid(e) then return end
		if save then
			net.Start("scp.lobby.name")
			net.WriteString(e:GetValue())
			net.SendToServer()
			UI.Sound("success")
		end
		e:Remove()
		if IsValid(parent) then parent:SetKeyboardInputEnabled(false) end
	end
	e.OnEnter = function() done(true) end
	e.OnLoseFocus = function() done(true) end
	e.OnKeyCodeTyped = function(s, key) if key == KEY_ESCAPE then done(false) end end
	return e
end

-- ------------------------------------------------------------- участник --
local function memberRow(parent, p)
	local row = vgui.Create("DPanel", parent)
	row:Dock(TOP)
	row:SetTall(UI.S(62))
	row:DockMargin(0, 0, 0, UI.S(6))
	row.talk = 0
	row.Paint = function(s, w, h)
		if not IsValid(p) then return end
		s.talk = UI.Approach(s.talk, p:IsSpeaking() and 1 or 0, 12)
		surface.SetDrawColor(255, 255, 255, 7 + 10 * s.talk)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(110, 196, 120, 255 * s.talk)
		surface.DrawRect(0, 0, UI.S(3), h)
		draw.SimpleText(p:SCPName(), SCP.Font("semibold", 16), UI.S(68), UI.S(21), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local _, idx = L.ModelOf(p)
		draw.SimpleText(C.ModelNames[idx] or "", SCP.Font("mono", 12), UI.S(68), UI.S(42), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local x = w - UI.S(16)
		if L.Mine and L.Mine.leader == p then
			draw.SimpleText("ЛИДЕР", SCP.Font("monobold", 11), x, h / 2, UI.Col.amber, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			x = x - UI.S(58)
		end
		if s.talk > 0.02 then
			UI.DrawIcon("mic", x - UI.S(8), h / 2, UI.S(18) * (0.85 + 0.15 * math.min(p:VoiceVolume() * 3, 1)), UI.Alpha(UI.Col.green, 255 * s.talk))
		end
	end
	local av = vgui.Create("AvatarImage", row)
	av:SetSize(UI.S(46), UI.S(46))
	av:SetPos(UI.S(10), UI.S(8))
	av:SetPlayer(p, 64)
	if L.IsLeader() and p ~= LocalPlayer() then
		local k = vgui.Create("SCP.IconButton", row)
		k:SetSize(UI.S(26), UI.S(26))
		k:SetIcon("close")
		k:SetTooltip("Исключить из отряда")
		row.PerformLayout = function(s, w, h) k:SetPos(w - UI.S(36), h / 2 - UI.S(13)) end
		k.DoClick = function()
			net.Start("scp.lobby.kick")
			net.WriteEntity(p)
			net.SendToServer()
		end
	end
	return row
end

-- ------------------------------------------------------------- экран --
function M.BuildLobby()
	local root = vgui.Create("DPanel")
	root:SetSize(ScrW(), ScrH())
	root:MakePopup()
	root:SetKeyboardInputEnabled(false) -- чтобы работал голос (клавиша рации/войса)
	root.Born = RealTime()
	local W, H = ScrW(), ScrH()

	root.Paint = function(s, w, h)
		M.PaintBackdrop(w, h, 150)
		local a = UI.Ease((RealTime() - s.Born) / 0.5)
		surface.SetAlphaMultiplier(a)
		UI.Logo(UI.S(78), UI.S(70), UI.S(46), 230)
		draw.SimpleText("ОТРЯД", SCP.Font("title", 34), UI.S(112), UI.S(56), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("ГРУППА БЫСТРОГО РЕАГИРОВАНИЯ" .. (L.Mine and (" · #" .. L.Mine.id) or ""), SCP.Font("mono", 12), UI.S(114), UI.S(86), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- подсказка про голос
		local me = LocalPlayer()
		local talk = me:IsSpeaking()
		local hint = talk and "ВАС СЛЫШИТ ОТРЯД" or ("УДЕРЖИВАЙТЕ [" .. voiceKey() .. "] — ГОЛОСОВОЙ КАНАЛ ОТРЯДА")
		UI.DrawIcon("mic", UI.S(56), h - UI.S(132), UI.S(18), talk and UI.Col.green or UI.Col.dim)
		draw.SimpleText(hint, SCP.Font("mono", 12), UI.S(74), h - UI.S(132), talk and UI.Col.green or UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
	end

	-- модель
	local mw, mh = UI.S(560), UI.S(760)
	local mdl = vgui.Create("DModelPanel", root)
	mdl:SetSize(mw, mh)
	mdl:SetPos(W / 2 - mw / 2 - UI.S(120), H / 2 - mh / 2 + UI.S(30))
	mdl:SetFOV(26)
	mdl:SetAmbientLight(Color(60, 60, 70))
	mdl:SetDirectionalLight(BOX_TOP, Color(255, 250, 240))
	mdl:SetDirectionalLight(BOX_FRONT, Color(120, 120, 130))
	mdl:SetDirectionalLight(BOX_RIGHT, Color(200, 40, 30))
	mdl.yaw, mdl.dragging = 20, nil
	local shownModel
	mdl.Think = function(s)
		local want = L.ModelOf(LocalPlayer())
		if want ~= shownModel then
			shownModel = want
			s:SetModel(want)
			local ent = s:GetEntity()
			if IsValid(ent) then
				local seq = ent:LookupSequence("idle_passive")
				if seq < 0 then seq = ent:LookupSequence("idle_all_01") end
				if seq >= 0 then ent:ResetSequence(seq) end
				s.Born = RealTime()
			end
		end
		if s.dragging then
			local x = gui.MouseX()
			s.yaw = s.yaw + (x - s.dragging) * 0.5
			s.dragging = x
		else
			s.yaw = UI.Approach(s.yaw, 20 + math.sin(RealTime() * 0.4) * 6, 1.5)
		end
	end
	mdl.OnMousePressed = function(s) s.dragging = gui.MouseX() end
	mdl.OnMouseReleased = function(s) s.dragging = nil end
	mdl.LayoutEntity = function(s, ent)
		ent:SetAngles(Angle(0, s.yaw, 0))
		ent:FrameAdvance(FrameTime())
		local c = ent:OBBCenter()
		s:SetLookAt(Vector(0, 0, c.z * 1.05))
		s:SetCamPos(Vector(150, 0, c.z * 1.15))
	end
	local basePaint = mdl.Paint
	mdl.Paint = function(s, w, h)
		-- подиум: круг света под ногами
		UI.Glow(w / 2, h - UI.S(70), w * 0.9, UI.S(120), Color(255, 255, 255, 18))
		local a = UI.Ease((RealTime() - (s.Born or 0)) / 0.5)
		surface.SetAlphaMultiplier(a)
		basePaint(s, w, h)
		surface.SetAlphaMultiplier(1)
	end

	-- имя над моделью (клик — сменить)
	local nameBtn = vgui.Create("DButton", root)
	nameBtn:SetText("")
	nameBtn:SetSize(UI.S(520), UI.S(60))
	nameBtn:SetPos(mdl:GetX() + mw / 2 - UI.S(260), mdl:GetY() - UI.S(40))
	nameBtn.hover = 0
	nameBtn.OnCursorEntered = function() UI.Sound("hover") end
	nameBtn.Paint = function(s, w, h)
		s.hover = UI.Approach(s.hover, s:IsHovered() and 1 or 0, 12)
		local name = LocalPlayer():SCPName()
		local font = SCP.Font("title", 34)
		local tw = UI.TextSize(name, font)
		draw.SimpleText(name, font, w / 2, h / 2 - UI.S(6), UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		UI.DrawIcon("pencil", w / 2 + tw / 2 + UI.S(18), h / 2 - UI.S(6), UI.S(16), UI.Alpha(UI.Col.text, 60 + 195 * s.hover))
		draw.SimpleText("НАЖМИТЕ, ЧТОБЫ СМЕНИТЬ ИМЯ", SCP.Font("mono", 10), w / 2, h - UI.S(4), UI.Alpha(UI.Col.dim, 120 * s.hover), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		return true
	end
	nameBtn.DoClick = function(s)
		UI.Sound("click")
		editName(root, s:GetX() + s:GetWide() / 2, s:GetY() + s:GetTall() / 2 - UI.S(6), UI.S(420))
	end

	-- стрелки выбора модели
	local function pick(dir)
		local _, i = L.ModelOf(LocalPlayer())
		i = (i - 1 + dir) % #C.Models + 1
		net.Start("scp.lobby.model")
		net.WriteUInt(i, 4)
		net.SendToServer()
		UI.Sound("swipe")
	end
	for _, d in ipairs({ { -1, "chevron_left", 0 }, { 1, "chevron_right", 1 } }) do
		local b = vgui.Create("SCP.IconButton", root)
		b:SetSize(UI.S(54), UI.S(54))
		b:SetIcon(d[2])
		b:SetPos(mdl:GetX() + (d[3] == 0 and UI.S(30) or (mw - UI.S(84))), mdl:GetY() + mh / 2 - UI.S(27))
		b.DoClick = function() pick(d[1]) end
	end

	-- подпись модели и точки
	local cap = vgui.Create("DPanel", root)
	cap:SetSize(mw, UI.S(50))
	cap:SetPos(mdl:GetX(), mdl:GetY() + mh - UI.S(10))
	cap.Paint = function(_, w, h)
		local _, i = L.ModelOf(LocalPlayer())
		draw.SimpleText(C.ModelNames[i] or "", SCP.Font("titlemed", 20), w / 2, UI.S(12), UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local n = #C.Models
		for k = 1, n do
			local x = w / 2 + (k - (n + 1) / 2) * UI.S(18)
			surface.SetDrawColor(255, 255, 255, k == i and 230 or 50)
			surface.DrawRect(x - UI.S(5), UI.S(34), UI.S(10), UI.S(3))
		end
	end

	-- отряд справа
	local sq = vgui.Create("DPanel", root)
	sq:SetSize(UI.S(420), UI.S(640))
	sq:SetPos(W - UI.S(420) - UI.S(56), H / 2 - UI.S(320))
	sq.Paint = function(_, w, h)
		UI.BlurPanel(sq, 3)
		surface.SetDrawColor(9, 10, 12, 200)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 16)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		local n = L.Mine and #L.Mine.members or 1
		draw.SimpleText("СОСТАВ ОТРЯДА", SCP.Font("title", 22), UI.S(20), UI.S(30), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(n .. " / " .. C.LobbyMax, SCP.Font("monobold", 15), w - UI.S(20), UI.S(30), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(UI.Col.red)
		surface.DrawRect(UI.S(20), UI.S(50), UI.S(28), UI.S(2))
	end
	local list = vgui.Create("SCP.Scroll", sq)
	list:SetPos(UI.S(14), UI.S(68))
	list:SetSize(sq:GetWide() - UI.S(28), sq:GetTall() - UI.S(68) - UI.S(72))
	local inv = vgui.Create("SCP.Button", sq)
	inv:SetSize(sq:GetWide() - UI.S(28), UI.S(46))
	inv:SetPos(UI.S(14), sq:GetTall() - UI.S(60))
	inv:SetLabel("ПРИГЛАСИТЬ ИГРОКА")
	inv:SetIcon("user_plus")
	inv.DoClick = openInvite

	local shownKey
	list.Think = function(s)
		local key = ""
		if L.Mine then
			key = tostring(L.Mine.leader)
			for _, p in ipairs(L.Mine.members) do key = key .. tostring(p) end
		end
		if key ~= shownKey then
			shownKey = key
			s:Clear()
			for _, p in ipairs(L.Mine and L.Mine.members or { LocalPlayer() }) do
				if IsValid(p) then memberRow(s, p) end
			end
		end
	end

	-- играть
	local play = vgui.Create("SCP.Button", root)
	play:SetSize(UI.S(380), UI.S(64))
	play:SetPos(mdl:GetX() + mw / 2 - UI.S(190), H - UI.S(64) - UI.S(44))
	play:SetFontStyle("title", 26)
	play:SetPrimary(true)
	play.Think = function(s)
		local leader = L.IsLeader()
		s:SetEnabled(leader)
		s:SetLabel(leader and "ИГРАТЬ" or "ОЖИДАНИЕ ЛИДЕРА…")
		s:SetIcon(leader and "play" or nil)
	end
	play.DoClick = function()
		UI.Sound("start")
		net.Start("scp.lobby.start")
		net.SendToServer()
	end

	-- назад
	local back = vgui.Create("SCP.Button", root)
	back:SetSize(UI.S(230), UI.S(46))
	back:SetPos(UI.S(48), H - UI.S(46) - UI.S(44))
	back:SetLabel("ПОКИНУТЬ ОТРЯД")
	back:SetIcon("arrow_left")
	back.DoClick = function()
		net.Start("scp.lobby.leave")
		net.SendToServer()
	end
	return root
end
