--[[
	TAB — «Личный состав объекта»: кто в меню, в лобби, на задании, погиб; этап задания; пинг.
	ПКМ по строке — заглушить голос / профиль Steam.
]]

local UI = SCP.UI
local SB = {}

local statusOf = {
	menu = { "В МЕНЮ", Color(150, 152, 158) },
	lobby = { "В ОТРЯДЕ", Color(110, 196, 120) },
	playing = { "НА ЗАДАНИИ", Color(232, 230, 224) },
	edit = { "РЕДАКТОР", Color(110, 160, 220) },
}

local function volumeModal(p)
	local bg, body = SCP.Modal("Громкость: " .. p:SCPName(), 460, 220, "volume")
	local sl = vgui.Create("SCP.Slider", body)
	sl:Dock(TOP)
	sl:Setup("Громкость голоса игрока", 0, 2, 2, function() return SCP.Settings.PlayerVolume(p) end,
		function(v) SCP.Settings.SetPlayerVolume(p, v) end, function(v) return math.Round(v * 100) .. "%" end)
	local mute = vgui.Create("SCP.Toggle", body)
	mute:Dock(TOP)
	mute:DockMargin(0, UI.S(12), 0, 0)
	mute:Setup("Заглушить полностью", function() return p:IsMuted() end, function(v) p:SetMuted(v) end)
end

local function rowMenu(p)
	local m = DermaMenu()
	if p ~= LocalPlayer() then
		m:AddOption("Громкость голоса…", function() volumeModal(p) end):SetIcon("icon16/sound.png")
	end
	m:AddOption(p:IsMuted() and "Включить голос" or "Заглушить голос", function() p:SetMuted(not p:IsMuted()) end):SetIcon("icon16/sound_mute.png")
	m:AddOption("Профиль Steam", function() p:ShowProfile() end):SetIcon("icon16/user.png")
	m:AddOption("Скопировать SteamID", function() SetClipboardText(p:SteamID()) end):SetIcon("icon16/page_copy.png")
	m:Open()
end

function SB.Open()
	if IsValid(SB.Panel) then return end
	local f = vgui.Create("DPanel")
	SB.Panel = f
	local w, h = UI.S(980), math.min(ScrH() - UI.S(120), UI.S(760))
	f:SetSize(w, h)
	f:Center()
	f:MakePopup()
	f:SetKeyboardInputEnabled(false)
	f.Born = RealTime()
	f.Paint = function(s, pw, ph)
		local t = UI.Ease((RealTime() - s.Born) / 0.2)
		s:SetAlpha(255 * t)
		UI.BlurPanel(s, 5)
		surface.SetDrawColor(8, 9, 11, 238)
		surface.DrawRect(0, 0, pw, ph)
		surface.SetDrawColor(255, 255, 255, 16)
		surface.DrawOutlinedRect(0, 0, pw, ph, 1)
		UI.Corners(0, 0, pw, ph, UI.S(16), Color(255, 255, 255, 110), 1)
		UI.Logo(UI.S(56), UI.S(54), UI.S(54), 235)
		draw.SimpleText("ЛИЧНЫЙ СОСТАВ ОБЪЕКТА", SCP.Font("title", 28), UI.S(98), UI.S(40), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(GetHostName() .. "  ·  " .. game.GetMap() .. "  ·  " .. player.GetCount() .. "/" .. game.MaxPlayers(), SCP.Font("mono", 12), UI.S(99), UI.S(70), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		-- статус задания справа
		local S = SCP.Story
		local st = S.Current and S.Current()
		local txt = (S.State.running and st) and (S.Chapter .. " · " .. st.title .. " · " .. S.State.stage .. "/" .. #S.Stages) or "ЗАДАНИЕ НЕ НАЧАТО"
		draw.SimpleText(S.Title or "", SCP.Font("titlemed", 18), pw - UI.S(28), UI.S(40), UI.Col.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		draw.SimpleText(string.upper(txt), SCP.Font("monobold", 11), pw - UI.S(28), UI.S(66), S.State.running and UI.Col.red or UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		if S.State.running then
			local el = CurTime() - S.State.started
			draw.SimpleText(string.format("%02d:%02d", math.floor(el / 60), math.floor(el % 60)), SCP.Font("mono", 11), pw - UI.S(28), UI.S(84), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		-- шапка таблицы
		local y = UI.S(112)
		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawRect(UI.S(24), y + UI.S(14), pw - UI.S(48), 1)
		local f2 = SCP.Font("monobold", 11)
		draw.SimpleText("ОПЕРАТИВНИК", f2, UI.S(86), y, UI.Col.faint)
		draw.SimpleText("СТАТУС", f2, pw - UI.S(380), y, UI.Col.faint)
		draw.SimpleText("ОТРЯД", f2, pw - UI.S(220), y, UI.Col.faint)
		draw.SimpleText("ПИНГ", f2, pw - UI.S(60), y, UI.Col.faint, TEXT_ALIGN_RIGHT)
	end

	local scroll = vgui.Create("SCP.Scroll", f)
	scroll:SetPos(UI.S(24), UI.S(138))
	scroll:SetSize(w - UI.S(48), h - UI.S(160))

	local plys = player.GetAll()
	local order = { playing = 1, lobby = 2, edit = 3, menu = 4 }
	table.sort(plys, function(a, b)
		local oa, ob = order[a:SCPState()] or 5, order[b:SCPState()] or 5
		if oa ~= ob then return oa < ob end
		return a:SCPName() < b:SCPName()
	end)
	for i, p in ipairs(plys) do
		local row = scroll:Add("DButton")
		row:SetText("")
		row:Dock(TOP)
		row:SetTall(UI.S(54))
		row:DockMargin(0, 0, 0, UI.S(4))
		row.Born = RealTime() + i * 0.03
		row.hover = 0
		row.DoRightClick = function() if IsValid(p) then rowMenu(p) end end
		row.DoClick = function() if IsValid(p) and p ~= LocalPlayer() then volumeModal(p) end end
		row.Paint = function(s, rw, rh)
			if not IsValid(p) then return true end
			s.hover = UI.Approach(s.hover, s:IsHovered() and 1 or 0, 12)
			local a = UI.Ease((RealTime() - s.Born) / 0.25)
			surface.SetAlphaMultiplier(a)
			local me = p == LocalPlayer()
			surface.SetDrawColor(255, 255, 255, (me and 12 or 6) + 10 * s.hover)
			surface.DrawRect(0, 0, rw, rh)
			local stt = statusOf[p:SCPState()] or statusOf.menu
			local dead = p:InGame() and not p:Alive()
			local scol = dead and UI.Col.red or stt[2]
			surface.SetDrawColor(scol)
			surface.DrawRect(0, 0, UI.S(2), rh)
			draw.SimpleText(p:SCPName(), SCP.Font("semibold", 17), UI.S(62), UI.S(19), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local _, idx, fac = SCP.Lobby.ModelOf(p)
			local sub = p:Nick() .. " · " .. fac.short
			if p:IsSuperAdmin() then sub = sub .. " · администратор" end
			draw.SimpleText(sub, SCP.Font("mono", 11), UI.S(62), UI.S(38), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if p:IsSpeaking() then UI.DrawIcon("mic", UI.S(62) + UI.TextSize(p:SCPName(), SCP.Font("semibold", 17)) + UI.S(14), UI.S(19), UI.S(14), UI.Col.green) end
			if p:IsMuted() then UI.DrawIcon("volume", UI.S(62) + UI.TextSize(p:SCPName(), SCP.Font("semibold", 17)) + UI.S(14), UI.S(19), UI.S(14), UI.Col.red) end
			draw.SimpleText(dead and "ПОГИБ" or stt[1], SCP.Font("monobold", 12), rw - UI.S(356), rh / 2, scol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local lid = p:SCPLobby()
			draw.SimpleText(lid > 0 and ("#" .. lid) or "—", SCP.Font("mono", 13), rw - UI.S(196), rh / 2, UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local ping = p:Ping()
			draw.SimpleText(p:IsBot() and "БОТ" or ping, SCP.Font("mono", 13), rw - UI.S(36), rh / 2, ping > 150 and UI.Col.amber or UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			surface.SetAlphaMultiplier(1)
			return true
		end
		local av = vgui.Create("AvatarImage", row)
		av:SetSize(UI.S(40), UI.S(40))
		av:SetPos(UI.S(10), UI.S(7))
		av:SetPlayer(p, 64)
		av:SetMouseInputEnabled(false)
	end
end

function SB.Close()
	if IsValid(SB.Panel) then SB.Panel:Remove() end
end

function GM:ScoreboardShow() SB.Open() return true end
function GM:ScoreboardHide() SB.Close() return true end
