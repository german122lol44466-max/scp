--[[
	Уведомления справа сверху: тонкая плашка с цветной полосой, выезжают и гаснут.
]]

local UI = SCP.UI
local list = {}
local kinds = {
	info = { col = UI.Col.text, icon = "info", snd = "notify" },
	ok = { col = UI.Col.green, icon = "check", snd = "success" },
	warn = { col = UI.Col.amber, icon = "warning", snd = "warning" },
	error = { col = UI.Col.red, icon = "warning", snd = "error" },
}

function SCP.Notify(text, kind)
	local k = kinds[kind] or kinds.info
	list[#list + 1] = { text = text, k = k, born = RealTime(), y = nil }
	if #list > 5 then table.remove(list, 1) end
	UI.Sound(k.snd)
end

net.Receive("scp.notify", function()
	SCP.Notify(net.ReadString(), net.ReadString())
end)

hook.Add("PostRenderVGUI", "scp.notify", function()
	local font = SCP.Font("medium", 17)
	local y0 = UI.S(28)
	local now = RealTime()
	for i = #list, 1, -1 do
		if now - list[i].born > 6 then table.remove(list, i) end
	end
	local y = y0
	for _, n in ipairs(list) do
		local t = now - n.born
		local a = math.min(t / 0.25, 1) * math.min((6 - t) / 0.5, 1)
		local tw = UI.TextSize(n.text, font)
		local w, h = tw + UI.S(64), UI.S(42)
		local x = ScrW() - w - UI.S(28) + (1 - UI.Ease(math.min(t / 0.3, 1))) * UI.S(40)
		n.y = n.y and UI.Approach(n.y, y, 12) or y
		surface.SetAlphaMultiplier(a)
		UI.BlurRect(x, n.y, w, h, 4)
		surface.SetDrawColor(10, 11, 13, 225)
		surface.DrawRect(x, n.y, w, h)
		surface.SetDrawColor(n.k.col)
		surface.DrawRect(x, n.y, UI.S(3), h)
		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawOutlinedRect(x, n.y, w, h, 1)
		UI.DrawIcon(n.k.icon, x + UI.S(24), n.y + h / 2, UI.S(18), n.k.col)
		draw.SimpleText(n.text, font, x + UI.S(44), n.y + h / 2, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetAlphaMultiplier(1)
		y = y + h + UI.S(8)
	end
end)
