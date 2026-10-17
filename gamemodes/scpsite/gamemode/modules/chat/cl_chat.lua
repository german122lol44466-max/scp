--[[
	Чат на клиенте: компактный, снизу слева. Закрыт — последние строки гаснут через 12 с;
	открыт — история с прокруткой и подсказка канала. Над пишущими — «печатает…».
]]

local UI = SCP.UI
local CH = SCP.Chat
CH.Lines = CH.Lines or {}

local MAX = 120
local W, LINE = 560, 24

function CH.Add(msg)
	msg.born = RealTime()
	msg.kind = msg.kind or "system"
	CH.Lines[#CH.Lines + 1] = msg
	if #CH.Lines > MAX then table.remove(CH.Lines, 1) end
	if msg.kind ~= "system" then
		local k = CH.Kinds[msg.kind]
		MsgC(k and k.col or color_white, (k and k.label and ("[" .. k.label .. "] ") or ""), msg.name and (msg.name .. ": ") or "", color_white, msg.text, "\n")
	end
	if IsValid(CH.Box) then CH.Box.dirty = true end
end

net.Receive("scp.chat.msg", function()
	local kind, ply, text = net.ReadString(), net.ReadEntity(), net.ReadString()
	CH.Add({ kind = kind, name = IsValid(ply) and ply:SCPName() or nil, ply = ply, text = text })
	if kind ~= "system" then chat.PlaySound() end
end)

-- Сообщения других аддонов и движка (chat.AddText) тоже показываем
CH.OrigAddText = CH.OrigAddText or chat.AddText
function chat.AddText(...)
	local parts = {}
	for _, v in ipairs({ ... }) do
		if isstring(v) then parts[#parts + 1] = v
		elseif type(v) == "Player" and IsValid(v) then parts[#parts + 1] = v:SCPName() end
	end
	CH.Add({ kind = "system", text = table.concat(parts) })
	return CH.OrigAddText(...)
end

hook.Add("ChatText", "scp.chat", function(index, name, text, kind)
	if kind == "joinleave" or kind == "none" or kind == "servermsg" then
		CH.Add({ kind = "system", text = text })
	end
	return true
end)

-- -------------------------------------------------------- рисование строк --
local function lineParts(m)
	local k = CH.Kinds[m.kind] or CH.Kinds.system
	if m.kind == "me" then return k, nil, "* " .. (m.name or "") .. " " .. m.text end
	local tag = k.label and (m.kind == "whisper" or m.kind == "yell") and (" (" .. k.label .. ")") or ""
	return k, (m.name and (m.name .. tag .. ": ") or nil), m.text
end

local function wrapMsg(m, font, width)
	local k, head, body = lineParts(m)
	local prefix = (k.label and m.kind ~= "whisper" and m.kind ~= "yell") and ("[" .. k.label .. "] ") or ""
	local full = prefix .. (head or "") .. body
	return k, prefix, head, UI.Wrap(full, font, width)
end

local function drawMsg(m, x, y, width, alpha)
	local font = SCP.Font("medium", 16)
	local k, prefix, head, lines = wrapMsg(m, font, width)
	for i, l in ipairs(lines) do
		local yy = y + (i - 1) * UI.S(LINE)
		-- тень
		draw.SimpleText(l, font, x + 1, yy + 1, Color(0, 0, 0, 200 * alpha))
		if i == 1 then
			local px = x
			if prefix ~= "" then
				draw.SimpleText(prefix, font, px, yy, UI.Alpha(k.col, 255 * alpha))
				px = px + UI.TextSize(prefix, font)
			end
			if head then
				draw.SimpleText(head, font, px, yy, Color(255, 255, 255, 255 * alpha))
				px = px + UI.TextSize(head, font)
			end
			local rest = string.sub(l, #prefix + #(head or "") + 1)
			draw.SimpleText(rest, font, px, yy, UI.Alpha(m.kind == "say" and UI.Col.text or k.col, 255 * alpha))
		else
			draw.SimpleText(l, font, x, yy, UI.Alpha(m.kind == "say" and UI.Col.text or k.col, 255 * alpha))
		end
	end
	return #lines * UI.S(LINE)
end

local function chatY() return ScrH() - UI.S(230) end

local function drawFeed()
	if IsValid(CH.Box) then return end
	local x, y = UI.S(32), chatY()
	local width = UI.S(W)
	local now = RealTime()
	local font = SCP.Font("medium", 16)
	-- снизу вверх
	local shown = 0
	for i = #CH.Lines, 1, -1 do
		local m = CH.Lines[i]
		local t = now - m.born
		if t > 12 or shown >= 8 then break end
		local a = math.min(t / 0.2, 1) * math.Clamp((12 - t) / 1.5, 0, 1)
		local _, _, _, lines = wrapMsg(m, font, width)
		y = y - #lines * UI.S(LINE)
		drawMsg(m, x, y, width, a)
		shown = shown + 1
	end
end

-- на задании — под интерфейсом (HUD), в меню и лобби — поверх экранов меню
hook.Add("HUDPaint", "scp.chat", function()
	if SCP.MyState() == "playing" or SCP.MyState() == "edit" then drawFeed() end
end)
hook.Add("PostRenderVGUI", "scp.chat", function()
	local st = SCP.MyState()
	if st == "menu" or st == "lobby" then drawFeed() end
end)

-- --------------------------------------------------------------- ввод --
local channelHint = {
	say = "РЯДОМ", radio = "РАЦИЯ — ВЕСЬ ОТРЯД", lobby = "ОТРЯД", ooc = "ОБЩИЙ ЧАТ", dead = "ПОГИБШИЕ",
}

local function typing(on)
	net.Start("scp.chat.typing")
	net.WriteBool(on)
	net.SendToServer()
end

function CH.Open(team)
	if IsValid(CH.Box) then return end
	local st = SCP.MyState()
	local f = vgui.Create("DPanel")
	CH.Box = f
	f:SetSize(UI.S(W) + UI.S(24), UI.S(360))
	f:SetPos(UI.S(20), chatY() - UI.S(360) + UI.S(62))
	f:MakePopup()
	f.Born = RealTime()
	f.Paint = function(s, w, h)
		s:SetAlpha(255 * UI.Ease((RealTime() - s.Born) / 0.15))
		UI.BlurPanel(s, 3)
		surface.SetDrawColor(8, 9, 11, 200)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local hist = vgui.Create("SCP.Scroll", f)
	hist:SetPos(UI.S(12), UI.S(10))
	hist:SetSize(f:GetWide() - UI.S(20), f:GetTall() - UI.S(66))
	local canvas = hist:Add("DPanel")
	canvas:Dock(TOP)
	canvas.Paint = function(s, w)
		local y = 0
		for _, m in ipairs(CH.Lines) do y = y + drawMsg(m, 0, y, w - UI.S(10), 1) + UI.S(2) end
	end
	local function relayout()
		local font = SCP.Font("medium", 16)
		local total = 0
		for _, m in ipairs(CH.Lines) do
			local _, _, _, lines = wrapMsg(m, font, hist:GetWide() - UI.S(16))
			total = total + #lines * UI.S(LINE) + UI.S(2)
		end
		canvas:SetTall(math.max(total, 1))
		timer.Simple(0, function() if IsValid(hist) then hist:GetVBar():AnimateTo(total, 0.1) end end)
	end
	relayout()
	f.Think = function(s) if s.dirty then s.dirty = false relayout() end end

	local entry = vgui.Create("SCP.Entry", f)
	entry:SetPos(UI.S(12), f:GetTall() - UI.S(48))
	entry:SetSize(f:GetWide() - UI.S(24), UI.S(38))
	entry:RequestFocus()
	if team and st == "playing" then entry:SetValue("/r ") entry:SetCaretPos(3) end
	entry.PaintOver = function(s, w, h)
		local kind = CH.Parse(s:GetValue())
		if not kind then
			kind = (st == "lobby" and "lobby") or ((st == "menu" or st == "edit") and "ooc") or "say"
			if st == "playing" and not LocalPlayer():Alive() then kind = "dead" end
		end
		local k = CH.Kinds[kind] or CH.Kinds.say
		draw.SimpleText(channelHint[kind] or string.upper(k.label or ""), SCP.Font("monobold", 11), w - UI.S(10), h / 2, UI.Alpha(k.col, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	local function close()
		typing(false)
		if IsValid(f) then f:Remove() end
	end
	entry.OnEnter = function(s)
		local text = string.Trim(s:GetValue())
		if text ~= "" then
			net.Start("scp.chat.say")
			net.WriteString(string.sub(text, 1, 300))
			net.SendToServer()
		end
		close()
	end
	entry.OnKeyCodeTyped = function(s, key)
		if key == KEY_ESCAPE then close() gui.HideGameUI() return true end
		if key == KEY_ENTER then s:OnEnter() return true end
	end
	typing(true)
end

hook.Add("PlayerBindPress", "scp.chat", function(ply, bind, pressed)
	if not pressed then return end
	if bind == "messagemode" then CH.Open(false) return true end
	if bind == "messagemode2" then CH.Open(true) return true end
end)

-- «печатает…» над головой
hook.Add("HUDPaint", "scp.chat.typing", function()
	if SCP.MyState() ~= "playing" then return end
	local me = LocalPlayer()
	for _, p in ipairs(player.GetAll()) do
		if p ~= me and p:Alive() and p:InGame() and p:GetNW2Bool("scp.typing") then
			local pos = p:GetPos() + Vector(0, 0, 80)
			local d = pos:Distance(EyePos())
			local s = pos:ToScreen()
			if s.visible and d < 600 then
				local dots = string.rep(".", math.floor(RealTime() * 3) % 4)
				draw.SimpleTextOutlined("печатает" .. dots, SCP.Font("medium", 13), s.x, s.y, Color(220, 220, 214, 200 * (1 - d / 600)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 120))
			end
		end
	end
end)
