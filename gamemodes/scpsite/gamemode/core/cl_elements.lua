--[[
	Элементы интерфейса в стиле терминалов Фонда.
	  SCP.MenuButton — большая кнопка главного меню (текст + полоска слева при наведении)
	  SCP.Button     — обычная кнопка (рамка, заливка при наведении), :SetIcon, :SetPrimary
	  SCP.IconButton — квадратная кнопка с иконкой
	  SCP.Scroll     — прокрутка с тонким ползунком
	  SCP.Entry      — поле ввода
]]

local UI = SCP.UI

-- ----------------------------------------------------------- MenuButton --
local MB = {}

function MB:Init()
	self:SetText("")
	self.Label = ""
	self.Sub = nil
	self.hover = 0
	self.Born = RealTime()
	self.Delay = 0
end

function MB:SetLabel(t, sub) self.Label = t self.Sub = sub end

function MB:OnCursorEntered() UI.Sound("hover") end

function MB:Paint(w, h)
	local appear = UI.Ease((RealTime() - self.Born - self.Delay) / 0.45)
	self.hover = UI.Approach(self.hover, (self:IsHovered() and self:IsEnabled()) and 1 or 0, 12)
	local hv = self.hover
	local off = (1 - appear) * -UI.S(30) + hv * UI.S(14)
	surface.SetAlphaMultiplier(appear * (self:IsEnabled() and 1 or 0.4))

	-- подсветка строки: заливка «въезжает» слева
	surface.SetMaterial(UI.Mat("scpsite/ui/fade_h.png"))
	surface.SetDrawColor(255, 255, 255, 30 * hv)
	surface.DrawTexturedRect(0, 0, w * 0.95 * UI.Ease(hv), h)
	if self.Index then
		draw.SimpleText(string.format("%02d", self.Index), SCP.Font("mono", 11), w - UI.S(20) - hv * UI.S(10), h / 2,
			UI.Alpha(UI.Col.dim, 80 + 175 * hv), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(255, 255, 255, 14 + 30 * hv)
		surface.DrawRect(UI.S(18), h - 1, (w - UI.S(40)) * (0.3 + 0.7 * hv), 1)
	end
	-- полоска
	surface.SetDrawColor(UI.Col.red.r, UI.Col.red.g, UI.Col.red.b, 255 * hv)
	surface.DrawRect(0, h * (0.5 - hv * 0.32), UI.S(3), h * hv * 0.64)

	local col = UI.LerpColor(hv, Color(200, 200, 196), color_white)
	draw.SimpleText(self.Label, SCP.Font("titlemed", 34), UI.S(18) + off, h / 2 - (self.Sub and UI.S(8) or 0), col,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	if self.Sub then
		draw.SimpleText(self.Sub, SCP.Font("mono", 13), UI.S(20) + off, h / 2 + UI.S(17), UI.Alpha(UI.Col.dim, 160 + 95 * hv),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	surface.SetAlphaMultiplier(1)
	return true
end

function MB:DoClickInternal() UI.Sound("click") end
vgui.Register("SCP.MenuButton", MB, "DButton")

-- ---------------------------------------------------------------- Button --
local B = {}

function B:Init()
	self:SetText("")
	self.Label = ""
	self.hover = 0
	self.press = 0
	self.Icon = nil
	self.Primary = false
	self.Danger = false
	self.FontName = SCP.Font("semibold", 16)
end

function B:SetLabel(t) self.Label = t end
function B:SetIcon(i) self.Icon = i end
function B:SetPrimary(b) self.Primary = b end
function B:SetDanger(b) self.Danger = b end
function B:SetFontStyle(style, size) self.FontName = SCP.Font(style, size) end
function B:OnCursorEntered() if self:IsEnabled() then UI.Sound("hover") end end
function B:DoClickInternal() UI.Sound("click") self.press = 1 end

function B:Paint(w, h)
	local en = self:IsEnabled()
	self.hover = UI.Approach(self.hover, (self:IsHovered() and en) and 1 or 0, 14)
	self.press = UI.Approach(self.press, 0, 8)
	local hv = self.hover
	local base = self.Danger and UI.Col.red or (self.Primary and Color(232, 230, 224) or Color(255, 255, 255))
	surface.SetAlphaMultiplier(en and 1 or 0.35)
	if self.Primary then
		surface.SetDrawColor(base.r, base.g, base.b, 220 + 35 * hv)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 60 * self.press)
		surface.DrawRect(0, 0, w, h)
	else
		surface.SetDrawColor(base.r, base.g, base.b, 6 + 22 * hv + 30 * self.press)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(base.r, base.g, base.b, 40 + 80 * hv)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	local tc = self.Primary and Color(12, 12, 14) or UI.LerpColor(hv, Color(214, 214, 210), color_white)
	if self.Danger and not self.Primary then tc = UI.LerpColor(hv, Color(230, 120, 112), Color(255, 160, 150)) end
	local font = self.FontName
	local tw = UI.TextSize(self.Label, font)
	local iw = self.Icon and (UI.S(18) + UI.S(8)) or 0
	local x = w / 2 - (tw + iw) / 2
	if self.Icon then UI.DrawIcon(self.Icon, x + UI.S(9), h / 2, UI.S(18), tc) end
	draw.SimpleText(self.Label, font, x + iw, h / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	surface.SetAlphaMultiplier(1)
	return true
end
vgui.Register("SCP.Button", B, "DButton")

-- ------------------------------------------------------------ IconButton --
local IB = {}
function IB:Init() self:SetText("") self.hover = 0 self.Icon = "close" self.Tip = nil end
function IB:SetIcon(i) self.Icon = i end
function IB:OnCursorEntered() UI.Sound("hover") end
function IB:DoClickInternal() UI.Sound("click") end
function IB:Paint(w, h)
	self.hover = UI.Approach(self.hover, self:IsHovered() and 1 or 0, 14)
	surface.SetDrawColor(255, 255, 255, 8 + 26 * self.hover)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(255, 255, 255, 30 + 60 * self.hover)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	UI.DrawIcon(self.Icon, w / 2, h / 2, math.min(w, h) * 0.55, UI.LerpColor(self.hover, UI.Col.dim, color_white))
	return true
end
vgui.Register("SCP.IconButton", IB, "DButton")

-- ---------------------------------------------------------------- Scroll --
local SC = {}
function SC:Init()
	local bar = self:GetVBar()
	bar:SetWide(UI.S(4))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(s, w, h)
		surface.SetDrawColor(255, 255, 255, s:IsHovered() and 90 or 40)
		surface.DrawRect(0, 0, w, h)
	end
end
vgui.Register("SCP.Scroll", SC, "DScrollPanel")

-- ----------------------------------------------------------------- Entry --
local E = {}
function E:Init()
	self:SetFont(SCP.Font("medium", 17))
	self:SetTextColor(UI.Col.text)
	self:SetCursorColor(UI.Col.text)
	self:SetHighlightColor(Color(206, 52, 46, 140))
	self:SetDrawLanguageID(false)
	self.Placeholder = ""
end
function E:SetPlaceholder(t) self.Placeholder = t end
function E:Paint(w, h)
	surface.SetDrawColor(255, 255, 255, self:HasFocus() and 16 or 8)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(255, 255, 255, self:HasFocus() and 90 or 30)
	surface.DrawRect(0, h - 1, w, 1)
	if self:GetValue() == "" and not self:HasFocus() then
		draw.SimpleText(self.Placeholder, self:GetFont(), UI.S(10), h / 2, UI.Col.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	self:DrawTextEntryText(self:GetTextColor(), self:GetHighlightColor(), self:GetCursorColor())
end
vgui.Register("SCP.Entry", E, "DTextEntry")

-- Модальное окно поверх всего: SCP.Modal(title, w, h) -> bg, body, frame
-- ESC и клик мимо закрывают самое верхнее окно (см. SCP.CloseTopModal, перехват ESC — modules/pause).
SCP.Modals = SCP.Modals or {}

function SCP.CloseTopModal()
	for i = #SCP.Modals, 1, -1 do
		local m = SCP.Modals[i]
		table.remove(SCP.Modals, i)
		if IsValid(m) then m:Remove() return true end
	end
	return false
end

function SCP.Modal(title, w, h, icon)
	local bg = vgui.Create("DPanel")
	bg:SetSize(ScrW(), ScrH())
	bg:MakePopup()
	bg:SetKeyboardInputEnabled(true)
	bg.Born = RealTime()
	bg:SetZPos(32000)
	bg.SCPCloseOnEsc = function(s) s:Remove() end
	SCP.Modals[#SCP.Modals + 1] = bg
	bg.Paint = function(s, pw, ph)
		local t = UI.Ease((RealTime() - s.Born) / 0.25)
		UI.BlurPanel(s, 4 * t)
		surface.SetDrawColor(0, 0, 0, 170 * t)
		surface.DrawRect(0, 0, pw, ph)
	end
	bg.OnMousePressed = function(s) s:Remove() end
	bg.OnKeyCodePressed = function(s, key) if key == KEY_ESCAPE then s:Remove() end end

	local f = vgui.Create("DPanel", bg)
	f:SetSize(UI.S(w), UI.S(h))
	f:Center()
	f.Born = RealTime()
	f.OnMousePressed = function() end
	f.Paint = function(s, pw, ph)
		local t = UI.Ease((RealTime() - s.Born) / 0.3)
		s:SetAlpha(255 * t)
		surface.SetDrawColor(11, 12, 14, 248)
		surface.DrawRect(0, 0, pw, ph)
		surface.SetDrawColor(255, 255, 255, 16)
		surface.DrawOutlinedRect(0, 0, pw, ph, 1)
		UI.Corners(0, 0, pw, ph, UI.S(14), Color(255, 255, 255, 120), 1)
		surface.SetDrawColor(UI.Col.red)
		surface.DrawRect(UI.S(24), UI.S(56), UI.S(28), UI.S(2))
		local x = UI.S(24)
		if icon then UI.DrawIcon(icon, x + UI.S(10), UI.S(32), UI.S(20), UI.Col.text) x = x + UI.S(30) end
		draw.SimpleText(title, SCP.Font("title", 24), x, UI.S(32), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	local close = vgui.Create("SCP.IconButton", f)
	close:SetSize(UI.S(30), UI.S(30))
	close:SetPos(f:GetWide() - UI.S(44), UI.S(17))
	close.DoClick = function() bg:Remove() end

	local body = vgui.Create("DPanel", f)
	body:SetPos(UI.S(24), UI.S(74))
	body:SetSize(f:GetWide() - UI.S(48), f:GetTall() - UI.S(94))
	body.Paint = function() end
	return bg, body, f
end

-- ---------------------------------------------------------------- Slider --
-- :Setup(label, min, max, decimals, get, set) — значение читается get(), пишется set(v)
local SL = {}
function SL:Init()
	self.Label, self.Min, self.Max, self.Dec = "", 0, 1, 2
	self.hover, self.drag = 0, false
	self:SetTall(UI.S(54))
	self:SetCursor("hand")
end
function SL:Setup(label, min, max, dec, get, set, fmt)
	self.Label, self.Min, self.Max, self.Dec, self.Get, self.Set, self.Fmt = label, min, max, dec, get, set, fmt
end
function SL:ValueFromX(x)
	local pad = UI.S(2)
	local frac = math.Clamp((x - pad) / (self:GetWide() - pad * 2), 0, 1)
	local v = self.Min + (self.Max - self.Min) * frac
	return math.Round(v, self.Dec)
end
function SL:OnMousePressed() self.drag = true self:MouseCapture(true) self.Set(self:ValueFromX(self:CursorPos())) end
function SL:OnMouseReleased() self.drag = false self:MouseCapture(false) UI.Sound("click") end
function SL:Think() if self.drag then self.Set(self:ValueFromX(self:CursorPos())) end end
function SL:Paint(w, h)
	self.hover = UI.Approach(self.hover, (self:IsHovered() or self.drag) and 1 or 0, 14)
	local v = self.Get()
	local frac = math.Clamp((v - self.Min) / (self.Max - self.Min), 0, 1)
	draw.SimpleText(self.Label, SCP.Font("medium", 15), 0, UI.S(14), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	local txt = self.Fmt and self.Fmt(v) or tostring(v)
	draw.SimpleText(txt, SCP.Font("monobold", 13), w, UI.S(14), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	local y = UI.S(38)
	surface.SetDrawColor(255, 255, 255, 20)
	surface.DrawRect(0, y, w, UI.S(3))
	surface.SetDrawColor(232, 230, 224)
	surface.DrawRect(0, y, w * frac, UI.S(3))
	local kx = w * frac
	UI.Circle(kx, y + UI.S(1.5), UI.S(6 + 2 * self.hover), Color(232, 230, 224))
	return true
end
vgui.Register("SCP.Slider", SL, "DPanel")

-- ---------------------------------------------------------------- Toggle --
local TG = {}
function TG:Init() self.Label = "" self.anim = 0 self:SetTall(UI.S(40)) self:SetCursor("hand") self:SetText("") end
function TG:Setup(label, get, set) self.Label, self.Get, self.Set = label, get, set end
function TG:DoClick() self.Set(not self.Get()) UI.Sound("toggle") end
function TG:Paint(w, h)
	local on = self.Get()
	self.anim = UI.Approach(self.anim, on and 1 or 0, 14)
	draw.SimpleText(self.Label, SCP.Font("medium", 15), 0, h / 2, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	local tw, th = UI.S(40), UI.S(20)
	local x, y = w - tw, h / 2 - th / 2
	surface.SetDrawColor(255, 255, 255, 20 + 200 * self.anim)
	surface.DrawRect(x, y, tw, th)
	surface.SetDrawColor(on and Color(12, 12, 14) or Color(150, 152, 158))
	surface.DrawRect(x + UI.S(3) + self.anim * (tw - th), y + UI.S(3), th - UI.S(6), th - UI.S(6))
	return true
end
vgui.Register("SCP.Toggle", TG, "DButton")

-- ---------------------------------------------------------------- Choice --
-- :Setup(label, { {id, text}, … }, get, set)
local CHC = {}
function CHC:Init() self:SetTall(UI.S(64)) self.btns = {} end
function CHC:Setup(label, opts, get, set)
	self.Label, self.Get, self.Set = label, get, set
	for _, o in ipairs(opts) do
		local b = vgui.Create("DButton", self)
		b:SetText("")
		b.hover = 0
		b.Paint = function(s, w, h)
			local on = get() == o[1]
			s.hover = UI.Approach(s.hover, s:IsHovered() and 1 or 0, 14)
			surface.SetDrawColor(on and 232 or 255, on and 230 or 255, on and 224 or 255, on and 240 or (8 + 18 * s.hover))
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255, on and 0 or 30)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(o[2], SCP.Font("semibold", 13), w / 2, h / 2, on and Color(12, 12, 14) or UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return true
		end
		b.DoClick = function() set(o[1]) UI.Sound("toggle") end
		self.btns[#self.btns + 1] = b
	end
end
function CHC:PerformLayout(w, h)
	local n = #self.btns
	local gap = UI.S(6)
	local bw = (w - gap * (n - 1)) / n
	for i, b in ipairs(self.btns) do
		b:SetPos((i - 1) * (bw + gap), UI.S(28))
		b:SetSize(bw, UI.S(34))
	end
end
function CHC:Paint(w)
	draw.SimpleText(self.Label, SCP.Font("medium", 15), 0, UI.S(12), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end
vgui.Register("SCP.Choice", CHC, "DPanel")

-- Заголовок раздела
function SCP.Section(parent, text)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP)
	p:SetTall(UI.S(40))
	p:DockMargin(0, UI.S(10), 0, UI.S(2))
	p.Paint = function(_, w, h)
		draw.SimpleText(string.upper(text), SCP.Font("monobold", 12), 0, h - UI.S(12), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(UI.Col.red)
		surface.DrawRect(0, h - 1, UI.S(18), 1)
		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawRect(UI.S(22), h - 1, w - UI.S(22), 1)
	end
	return p
end

-- Окно ввода текста: SCP.Prompt(заголовок, подсказка, текущее, ok(текст), [макс. символов])
-- Enter — сохранить, ESC / «Отмена» / клик мимо — закрыть. Фокус ставится сам.
function SCP.Prompt(title, hint, value, ok, maxLen)
	local bg, body = SCP.Modal(title, 520, 250, "pencil")
	local lbl = vgui.Create("DLabel", body)
	lbl:Dock(TOP)
	lbl:SetFont(SCP.Font("regular", 14))
	lbl:SetTextColor(UI.Col.dim)
	lbl:SetText(hint or "")
	lbl:SetTall(UI.S(24))
	local e = vgui.Create("SCP.Entry", body)
	e:Dock(TOP)
	e:DockMargin(0, UI.S(6), 0, 0)
	e:SetTall(UI.S(44))
	e:SetFont(SCP.Font("semibold", 20))
	e:SetValue(value or "")
	e:SetUpdateOnType(true)
	if maxLen then
		e.AllowInput = function(s, ch)
			return utf8.len(s:GetValue() or "") >= maxLen
		end
	end
	local row = vgui.Create("DPanel", body)
	row:Dock(BOTTOM)
	row:SetTall(UI.S(42))
	row.Paint = function() end
	local function submit()
		local v = string.Trim(e:GetValue() or "")
		bg:Remove()
		if v ~= "" then ok(v) end
	end
	local save = vgui.Create("SCP.Button", row)
	save:Dock(RIGHT)
	save:SetWide(UI.S(170))
	save:SetPrimary(true)
	save:SetLabel("Сохранить")
	save:SetIcon("check")
	save.DoClick = submit
	local cancel = vgui.Create("SCP.Button", row)
	cancel:Dock(RIGHT)
	cancel:DockMargin(0, 0, UI.S(8), 0)
	cancel:SetWide(UI.S(130))
	cancel:SetLabel("Отмена")
	cancel.DoClick = function() bg:Remove() end
	e.OnEnter = submit
	-- фокус — со следующего кадра, когда окно уже на экране
	timer.Simple(0, function()
		if IsValid(e) then
			e:RequestFocus()
			e:SelectAllText(true)
			e:SetCaretPos(utf8.len(e:GetValue() or "") or 0)
		end
	end)
	return bg, e
end
