--[[
	Управление экранами меню: главное → выбор режима → лобби → игра.
	Экран выбирается по состоянию игрока на сервере (scp.state), переходы — с затемнением.
	Камера в меню/лобби стоит на точках menu_cam / lobby_cam (scp_edit), с лёгким «дыханием».
]]

local UI = SCP.UI
local M = SCP.Menu
M.Screen = M.Screen or nil   -- "main" | "select" | "lobby"
M.Panel = M.Panel or nil

function M.CloseAll()
	if IsValid(M.Panel) then M.Panel:Remove() end
	M.Panel, M.Screen = nil, nil
	gui.EnableScreenClicker(false)
end

-- Открыть экран сразу (без затемнения)
function M.Show(screen)
	if IsValid(M.Panel) then M.Panel:Remove() end
	M.Screen = screen
	if screen == "main" then M.Panel = M.BuildMain()
	elseif screen == "select" then M.Panel = M.BuildSelect()
	elseif screen == "lobby" then M.Panel = M.BuildLobby()
	end
end

-- Переход с затемнением
function M.Go(screen, cb)
	if M.Switching then return end
	M.Switching = true
	UI.Fade(0.45, 0.25, 0.6, function()
		M.Show(screen)
		M.Switching = false
		if cb then cb() end
	end)
end

-- Какой экран должен быть сейчас
function M.Sync()
	local st = SCP.MyState()
	if st == "playing" or st == "edit" then
		if M.Screen then M.CloseAll() end
		return
	end
	if st == "lobby" then
		if M.Screen ~= "lobby" then
			if M.Screen then M.Go("lobby") else M.Show("lobby") end
		end
		return
	end
	-- menu
	if M.Screen == "lobby" then M.Go("select")
	elseif not M.Screen then M.Show("main") end
end

local lastState
hook.Add("Think", "scp.menu", function()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	local st = SCP.MyState()
	if st ~= lastState then
		lastState = st
		M.Sync()
	end
	if M.Screen and not IsValid(M.Panel) and not M.Switching then M.Show(M.Screen) end
end)

-- ------------------------------------------------------------- камера --
hook.Add("SCP.CalcView", "scp.menu", function(ply, origin, angles, fov)
	local st = SCP.MyState()
	if st ~= "menu" and st ~= "lobby" then return end
	local P = SCP.Points
	local p = (st == "lobby" and P.First("lobby_cam")) or P.First("menu_cam")
	if not p then
		return { origin = Vector(0, 0, -16000), angles = Angle(0, 0, 0), fov = 70, drawviewer = false }
	end
	local t = RealTime()
	local ang = Angle(p.ang.p + math.sin(t * 0.21) * 0.8, p.ang.y + math.sin(t * 0.13) * 1.6, math.sin(t * 0.17) * 0.4)
	return { origin = p.pos + Vector(0, 0, math.sin(t * 0.3) * 1.2), angles = ang, fov = 72, drawviewer = false }
end)

-- В меню без точки камеры — просто чёрный фон (иначе видно «пустоту» под картой)
hook.Add("PreDrawHUD", "scp.menu.nocam", function()
	local st = SCP.MyState()
	if (st == "menu" or st == "lobby") and not SCP.Points.First("menu_cam") then
		cam.Start2D()
		surface.SetDrawColor(6, 7, 9)
		surface.DrawRect(0, 0, ScrW(), ScrH())
		cam.End2D()
	end
end)

-- -------------------------------------------------------------- музыка --
local music, musicVol, musicWant = nil, 0, 0
local function ensureMusic()
	if music or M.Loading then return end
	M.Loading = true
	sound.PlayFile("sound/scpsite/music/menu.mp3", "noblock noplay", function(ch)
		M.Loading = false
		if not IsValid(ch) then return end
		music = ch
		ch:EnableLooping(true)
		ch:SetVolume(0)
		ch:Play()
	end)
end

hook.Add("Think", "scp.menu.music", function()
	local st = SCP.MyState()
	local want = (st == "menu" or st == "lobby") and GetConVar("scp_music"):GetFloat() or 0
	if want > 0 then ensureMusic() end
	if not IsValid(music) then return end
	musicVol = UI.Approach(musicVol, want, want > musicVol and 0.8 or 1.6)
	music:SetVolume(musicVol * 0.55)
	if musicVol < 0.005 and want == 0 then
		music:Stop()
		music = nil
	end
end)

CreateClientConVar("scp_music", "1", true, false, "Громкость музыки меню (0..1)", 0, 1)

-- ---------------------------------------------------- общий фон экранов --
-- Живой слой: частицы пыли, полоса сканирования, огромная эмблема справа
local motes
local function ambient(w, h)
	if not motes then
		motes = {}
		for i = 1, 70 do
			motes[i] = { x = math.random(), y = math.random(), s = math.Rand(1, 3), v = math.Rand(0.004, 0.02), a = math.Rand(30, 110), ph = math.Rand(0, 6) }
		end
	end
	local t = RealTime()
	-- эмблема
	local size = h * 1.15
	surface.SetMaterial(UI.Mat("scpsite/logo.png"))
	surface.SetDrawColor(255, 255, 255, 9)
	surface.DrawTexturedRectRotated(w * 0.78, h * 0.55, size, size, t * 2.5)
	surface.SetDrawColor(255, 255, 255, 5)
	surface.DrawTexturedRectRotated(w * 0.78, h * 0.55, size * 0.62, size * 0.62, -t * 4)
	-- частицы
	for _, m in ipairs(motes) do
		local y = (m.y - t * m.v) % 1
		local x = m.x + math.sin(t * 0.3 + m.ph) * 0.01
		UI.Circle(x * w, y * h, UI.S(m.s), Color(230, 228, 220, m.a * (0.6 + 0.4 * math.sin(t + m.ph))))
	end
	-- полоса сканирования
	local sy = (t * 0.08 % 1.2 - 0.1) * h
	surface.SetMaterial(UI.Mat("scpsite/ui/fade_v.png"))
	surface.SetDrawColor(255, 255, 255, 10)
	surface.DrawTexturedRect(0, sy - UI.S(120), w, UI.S(120))
	surface.SetDrawColor(255, 255, 255, 22)
	surface.DrawRect(0, sy, w, 1)
end
M.Ambient = ambient

-- Заголовок с редкими глитчами (смещённые красная и голубая копии)
function M.GlitchText(text, font, x, y, col, ax, ay)
	local t = RealTime()
	local g = (math.sin(t * 1.7) > 0.985 or math.sin(t * 0.63 + 1) > 0.992) and 1 or 0
	if g > 0 then
		local o = UI.S(math.random(2, 5))
		draw.SimpleText(text, font, x - o, y, Color(255, 40, 40, 150), ax, ay)
		draw.SimpleText(text, font, x + o, y + UI.S(1), Color(40, 220, 255, 150), ax, ay)
	end
	draw.SimpleText(text, font, x, y, col, ax, ay)
end

function M.PaintBackdrop(w, h, darkLeft)
	-- затемнение слева (под кнопки) и снизу
	surface.SetMaterial(UI.Mat("scpsite/ui/fade_h.png"))
	surface.SetDrawColor(0, 0, 0, darkLeft or 235)
	surface.DrawTexturedRect(0, 0, w * 0.62, h)
	surface.SetMaterial(UI.Mat("scpsite/ui/fade_v.png"))
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawTexturedRect(0, h * 0.55, w, h * 0.45)
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawTexturedRectUV(0, 0, w, h * 0.25, 0, 1, 1, 0)
	ambient(w, h)
	UI.Vignette(0, 0, w, h, 255)
	UI.Scanlines(0, 0, w, h, 22)
	UI.Grain(0, 0, w, h, 10)
	-- рамка-уголки по краям экрана
	UI.Corners(UI.S(20), UI.S(20), w - UI.S(40), h - UI.S(40), UI.S(28), Color(255, 255, 255, 40), 1)
end

-- Мигающий курсор терминала
function M.Cursor()
	return (math.floor(RealTime() * 2) % 2 == 0) and "_" or " "
end
