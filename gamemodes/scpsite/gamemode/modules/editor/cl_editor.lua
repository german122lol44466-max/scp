--[[
	Редактор точек: маркеры в мире, список слева и панель по зажатому C.
]]

local UI = SCP.UI
local P = SCP.Points
local Ed = {}
SCP.Editor = Ed

net.Receive("scp.edit", function()
	local on = net.ReadBool()
	SCP.State = on and "edit" or "menu"
	if on and SCP.Menu.CloseAll then SCP.Menu.CloseAll() end
	if not on and IsValid(Ed.Panel) then Ed.Panel:Remove() end
end)

local function send(id, action)
	net.Start("scp.edit.act")
	net.WriteString(id)
	net.WriteString(action)
	net.SendToServer()
end

-- Просмотр камеры (меню/лобби) на 4 секунды
local preview, previewEnd
function Ed.Preview(id)
	local p = P.First(id)
	if not p then SCP.Notify("Точка не установлена", "warn") return end
	preview, previewEnd = p, RealTime() + 4
	if IsValid(Ed.Panel) then Ed.Panel:Remove() end
end

hook.Add("SCP.CalcView", "scp.editor.preview", function()
	if preview and RealTime() < previewEnd then
		return { origin = preview.pos, angles = preview.ang, fov = 75, drawviewer = true }
	end
	preview = nil
end)

-- ------------------------------------------------------------- панель --
function Ed.Open()
	if IsValid(Ed.Panel) then return end
	local f = vgui.Create("DPanel")
	Ed.Panel = f
	f:SetSize(UI.S(560), math.min(ScrH() - UI.S(80), UI.S(860)))
	f:SetPos(UI.S(30), ScrH() / 2 - f:GetTall() / 2)
	f:MakePopup()
	f:SetKeyboardInputEnabled(false)
	f.Born = RealTime()
	f.Paint = function(s, w, h)
		s:SetAlpha(255 * UI.Ease((RealTime() - s.Born) / 0.2))
		UI.BlurPanel(s, 4)
		surface.SetDrawColor(9, 10, 12, 236)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 16)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		UI.Logo(UI.S(38), UI.S(38), UI.S(34), 230)
		draw.SimpleText("РЕДАКТОР ТОЧЕК", SCP.Font("title", 24), UI.S(66), UI.S(28), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(game.GetMap() .. " · сохраняется сразу", SCP.Font("mono", 13), UI.S(67), UI.S(52), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local scroll = vgui.Create("SCP.Scroll", f)
	scroll:SetPos(UI.S(16), UI.S(76))
	scroll:SetSize(f:GetWide() - UI.S(32), f:GetTall() - UI.S(92))

	local lastGroup
	for _, t in ipairs(P.Types) do
		if t.group ~= lastGroup then
			lastGroup = t.group
			local hdr = scroll:Add("DPanel")
			hdr:Dock(TOP)
			hdr:SetTall(UI.S(30))
			hdr:DockMargin(0, UI.S(8), 0, 0)
			hdr.Paint = function(_, w, h)
				draw.SimpleText(string.upper(t.group), SCP.Font("monobold", 13), 0, h / 2, UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				surface.SetDrawColor(255, 255, 255, 14)
				surface.DrawRect(UI.S(90), h / 2, w - UI.S(90), 1)
			end
		end
		local row = scroll:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(UI.S(64))
		row:DockMargin(0, UI.S(4), 0, 0)
		row.Paint = function(_, w, h)
			surface.SetDrawColor(255, 255, 255, 6)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(t.col)
			surface.DrawRect(0, 0, UI.S(3), h)
			local n = P.Count(t.id)
			local ok = not t.need or n >= t.need
			draw.SimpleText(t.name, SCP.Font("semibold", 15), UI.S(14), UI.S(17), UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local info = t.single and (n > 0 and "установлена" or "не установлена") or ("точек: " .. n)
			if t.need and not ok then info = info .. "  · нужно " .. t.need end
			draw.SimpleText(info, SCP.Font("mono", 12), UI.S(14), UI.S(44), ok and UI.Col.dim or UI.Col.amber, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		local x = row:GetWide()
		local btns = {
			{ "plus", t.cam and "Сюда (по взгляду)" or "Поставить здесь", function() send(t.id, "add") end },
			{ "minus", "Удалить ближайшую", function() send(t.id, "remove") end },
			{ "trash", "Удалить все", function() send(t.id, "clear") end },
		}
		if t.cam then
			btns[#btns + 1] = { "eye", "Посмотреть", function() Ed.Preview(t.id) end }
		else
			btns[#btns + 1] = { "map_pin", "Телепорт к первой", function() send(t.id, "tp") end }
		end
		row.PerformLayout = function(s, w, h)
			for i, b in ipairs(s.Btns or {}) do
				b:SetSize(UI.S(34), UI.S(34))
				b:SetPos(w - i * UI.S(40) - UI.S(4), h / 2 - UI.S(17))
			end
		end
		row.Btns = {}
		for i = #btns, 1, -1 do
			local d = btns[i]
			local b = vgui.Create("SCP.IconButton", row)
			b:SetIcon(d[1])
			b:SetTooltip(d[2])
			b.DoClick = d[3]
			row.Btns[#row.Btns + 1] = b
		end
	end
end

function Ed.Close()
	if IsValid(Ed.Panel) then Ed.Panel:Remove() end
end

hook.Add("OnContextMenuOpen", "scp.editor", function()
	if SCP.InEdit(LocalPlayer()) then Ed.Open() return false end
end)
hook.Add("OnContextMenuClose", "scp.editor", function()
	if SCP.InEdit(LocalPlayer()) then Ed.Close() return false end
end)

-- ----------------------------------------------------- маркеры в мире --
hook.Add("PostDrawTranslucentRenderables", "scp.editor", function(depth, sky)
	if sky or not SCP.InEdit(LocalPlayer()) then return end
	render.SetColorMaterial()
	for _, t in ipairs(P.Types) do
		for _, p in ipairs(P.Get(t.id)) do
			local c = t.col
			if t.cam then
				render.DrawWireframeBox(p.pos, p.ang, Vector(-6, -8, -5), Vector(8, 8, 5), c, true)
				render.DrawLine(p.pos, p.pos + p.ang:Forward() * 60, c, true)
			else
				render.DrawSphere(p.pos + Vector(0, 0, 4), 6, 12, 12, Color(c.r, c.g, c.b, 120))
				render.DrawLine(p.pos, p.pos + Vector(0, 0, 72), Color(c.r, c.g, c.b, 160), true)
				render.DrawLine(p.pos + Vector(0, 0, 4), p.pos + Vector(0, 0, 4) + p.ang:Forward() * 28, c, true)
			end
		end
	end
end)

hook.Add("HUDPaint", "scp.editor", function()
	local me = LocalPlayer()
	if not SCP.InEdit(me) then return end
	local font = SCP.Font("semibold", 14)
	for _, t in ipairs(P.Types) do
		for i, p in ipairs(P.Get(t.id)) do
			local pos = t.cam and p.pos or (p.pos + Vector(0, 0, 80))
			local d = pos:Distance(EyePos())
			if d < 3000 then
				local s = pos:ToScreen()
				if s.visible then
					local a = math.Clamp(1 - d / 3000, 0.25, 1) * 255
					local label = t.name .. ((not t.single) and (" #" .. i) or "")
					draw.SimpleTextOutlined(label, font, s.x, s.y, Color(t.col.r, t.col.g, t.col.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, a * 0.8))
				end
			end
		end
	end
	-- шапка и чего не хватает
	local x, y = ScrW() / 2, UI.S(26)
	draw.SimpleTextOutlined("РЕДАКТОР · зажмите C — панель точек · scp_edit — выход", SCP.Font("monobold", 15), x, y, UI.Col.amber, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	local miss = P.Missing()
	if #miss > 0 then
		local names = {}
		for _, t in ipairs(miss) do names[#names + 1] = t.name end
		draw.SimpleTextOutlined("Не хватает для сюжета: " .. table.concat(names, ", "), SCP.Font("medium", 14), x, y + UI.S(22), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	else
		draw.SimpleTextOutlined("Все точки сюжета расставлены", SCP.Font("medium", 14), x, y + UI.S(22), UI.Col.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end
end)
