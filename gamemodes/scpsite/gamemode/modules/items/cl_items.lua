--[[
	Инвентарь на клиенте и чтение документов.
]]

local UI = SCP.UI
local I = SCP.Items
I.Mine = I.Mine or {}

net.Receive("scp.inv.sync", function()
	I.Mine = net.ReadTable()
	hook.Run("SCP.InventoryChanged")
end)

function I.UseSlot(slot)
	local it = I.Mine[slot]
	if not it then return end
	if it.id == "note" then I.Read(it.data and it.data.note) return end
	net.Start("scp.inv.use")
	net.WriteUInt(slot, 5)
	net.SendToServer()
end

function I.DropSlot(slot)
	net.Start("scp.inv.drop")
	net.WriteUInt(slot, 5)
	net.SendToServer()
end

-- Документ: бумага на тёмном фоне, машинописный шрифт
function I.Read(index)
	local n = SCP.Notes[index or 0]
	if not n then return end
	UI.Sound("open")
	surface.PlaySound("scpsite/fx/paper.mp3")
	local bg, body, f = SCP.Modal(n.title, 640, 720, "clipboard")
	f.Paint = function(s, w, h)
		local t = UI.Ease((RealTime() - s.Born) / 0.3)
		s:SetAlpha(255 * t)
		surface.SetDrawColor(226, 221, 206)
		surface.DrawRect(0, 0, w, h)
		surface.SetMaterial(UI.Mat("scpsite/ui/grain.png"))
		surface.SetDrawColor(120, 100, 70, 40)
		surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, w / 256, h / 256)
		UI.Logo(w - UI.S(60), UI.S(60), UI.S(60), 40)
		draw.SimpleText(n.title, SCP.Font("monobold", 20), UI.S(36), UI.S(40), Color(30, 28, 26))
		draw.SimpleText("ФОНД SCP · ОБЪЕКТ-19 · ДЛЯ СЛУЖЕБНОГО ПОЛЬЗОВАНИЯ", SCP.Font("mono", 11), UI.S(36), UI.S(70), Color(140, 40, 34))
		surface.SetDrawColor(30, 28, 26, 120)
		surface.DrawRect(UI.S(36), UI.S(90), w - UI.S(72), 1)
	end
	body:SetPos(UI.S(36), UI.S(108))
	body:SetSize(f:GetWide() - UI.S(72), f:GetTall() - UI.S(140))
	local font = SCP.Font("mono", 16)
	local y = 0
	body.Paint = function(_, w)
		y = 0
		for _, para in ipairs(n.text) do
			for _, l in ipairs(UI.Wrap(para, font, w)) do
				draw.SimpleText(l, font, 0, y, Color(34, 32, 30))
				y = y + UI.S(24)
			end
			y = y + UI.S(12)
		end
	end
	for _, c in ipairs(f:GetChildren()) do
		if c.Icon then c.Paint = function(s, w, h) UI.DrawIcon("close", w / 2, h / 2, w * 0.55, Color(30, 28, 26)) return true end end
	end
end
