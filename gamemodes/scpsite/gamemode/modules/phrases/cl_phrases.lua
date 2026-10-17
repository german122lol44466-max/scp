--[[
	Фразы на клиенте: облачко над головой (3 с) и строка в чате; круговое меню быстрых команд (Z).
]]

local UI = SCP.UI
local PH = SCP.Phrases
local bubbles = {}

net.Receive("scp.phrase", function()
	local ply, text = net.ReadEntity(), net.ReadString()
	if not IsValid(ply) then return end
	bubbles[ply] = { text = text, born = RealTime() }
end)

-- «Увидел лицо» — удар по экрану: вспышка, толчок камеры, звон
local sawAt = 0
hook.Add("SCP.Saw096", "scp.phrases", function()
	sawAt = RealTime()
	SCP.Camera.Punch(Angle(-4, 0, 6))
	surface.PlaySound("scpsite/fx/horror" .. math.random(1, 4) .. ".mp3")
end)

hook.Add("HUDPaint", "scp.phrases.saw", function()
	local t = RealTime() - sawAt
	if t > 2.5 then return end
	local a = math.Clamp(1 - t / 2.5, 0, 1)
	surface.SetDrawColor(255, 255, 255, 120 * a * a)
	surface.DrawRect(0, 0, ScrW(), ScrH())
	SCP.UI.Vignette(0, 0, ScrW(), ScrH(), 255 * a)
end)

hook.Add("HUDPaint", "scp.phrases.bubbles", function()
	if SCP.MyState() ~= "playing" then return end
	local me = LocalPlayer()
	local font = SCP.Font("semibold", 15)
	for ply, b in pairs(bubbles) do
		local t = RealTime() - b.born
		if not IsValid(ply) or t > 3.5 then bubbles[ply] = nil
		elseif ply ~= me and ply:Alive() then
			local pos = ply:GetPos() + Vector(0, 0, 90)
			local d = pos:Distance(EyePos())
			local s = pos:ToScreen()
			if s.visible and d < PH.Range then
				local a = math.min(t / 0.2, 1) * math.min((3.5 - t) / 0.4, 1) * math.Clamp(1.2 - d / PH.Range, 0, 1)
				local tw = UI.TextSize(b.text, font)
				local w, h = tw + UI.S(24), UI.S(30)
				local y = s.y - h - (1 - math.min(t / 0.2, 1)) * -UI.S(10)
				surface.SetAlphaMultiplier(a)
				surface.SetDrawColor(10, 11, 13, 215)
				surface.DrawRect(s.x - w / 2, y, w, h)
				surface.SetDrawColor(255, 255, 255, 30)
				surface.DrawOutlinedRect(s.x - w / 2, y, w, h, 1)
				draw.NoTexture()
				surface.SetDrawColor(10, 11, 13, 215)
				surface.DrawPoly({ { x = s.x - UI.S(6), y = y + h }, { x = s.x + UI.S(6), y = y + h }, { x = s.x, y = y + h + UI.S(7) } })
				draw.SimpleText(b.text, font, s.x, y + h / 2, UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				surface.SetAlphaMultiplier(1)
			end
		end
	end
end)

-- ------------------------------------------------- Z — команды отряду --
SCP.Radial("squad", {
	key = KEY_Z, convar = "scp_phrase_key", title = "КОМАНДЫ",
	items = function() return PH.Quick end,
	pick = function(i)
		net.Start("scp.phrase.req")
		net.WriteUInt(i, 4)
		net.SendToServer()
	end,
})
