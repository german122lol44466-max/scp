--[[
	Лобби на клиенте: синхронизация, приглашения (всплывающая карточка с «Принять/Отклонить»).
]]

local UI = SCP.UI
local L = SCP.Lobby

net.Receive("scp.lobby.sync", function()
	local id = net.ReadUInt(16)
	if id == 0 then L.Mine = nil return end
	local lobby = { id = id, leader = net.ReadEntity(), started = net.ReadBool(), chapter = net.ReadUInt(4), members = {} }
	for _ = 1, net.ReadUInt(5) do lobby.members[#lobby.members + 1] = net.ReadEntity() end
	L.Mine = lobby
end)

function L.IsLeader()
	return L.Mine and L.Mine.leader == LocalPlayer()
end

-- ------------------------------------------------------------ приглашения --
L.Invites = L.Invites or {}

local function answer(inv, yes)
	net.Start("scp.lobby.answer")
	net.WriteUInt(inv.id, 16)
	net.WriteBool(yes)
	net.SendToServer()
	if IsValid(inv.panel) then inv.panel:Remove() end
	table.RemoveByValue(L.Invites, inv)
end

net.Receive("scp.lobby.invited", function()
	local inv = { id = net.ReadUInt(16), from = net.ReadEntity(), born = RealTime() }
	if not IsValid(inv.from) then return end
	for _, o in ipairs(L.Invites) do if o.id == inv.id then return end end
	L.Invites[#L.Invites + 1] = inv
	UI.Sound("notify")
	surface.PlaySound("scpsite/fx/radio_beep.mp3")

	local p = vgui.Create("DPanel")
	inv.panel = p
	p:SetSize(UI.S(400), UI.S(150))
	p:SetPos(ScrW() - UI.S(400) - UI.S(28), ScrH() * 0.5 - UI.S(75) + (#L.Invites - 1) * UI.S(160))
	p:MakePopup()
	p:SetKeyboardInputEnabled(false)
	p.Paint = function(s, w, h)
		local t = RealTime() - inv.born
		if t > 30 then answer(inv, false) return end
		s:SetAlpha(255 * UI.Ease(t / 0.3))
		UI.BlurPanel(s, 4)
		surface.SetDrawColor(10, 11, 13, 240)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 22)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		surface.SetDrawColor(UI.Col.red)
		surface.DrawRect(0, 0, UI.S(3), h)
		surface.DrawRect(0, h - UI.S(2), w * (1 - t / 30), UI.S(2))
		draw.SimpleText("ПРИГЛАШЕНИЕ В ОТРЯД", SCP.Font("monobold", 12), UI.S(78), UI.S(26), UI.Col.red)
		draw.SimpleText(IsValid(inv.from) and inv.from:SCPName() or "?", SCP.Font("title", 22), UI.S(78), UI.S(42), UI.Col.text)
		draw.SimpleText("зовёт вас в свой отряд", SCP.Font("regular", 14), UI.S(78), UI.S(70), UI.Col.dim)
	end
	local av = vgui.Create("AvatarImage", p)
	av:SetSize(UI.S(48), UI.S(48))
	av:SetPos(UI.S(18), UI.S(24))
	av:SetPlayer(inv.from, 64)
	local yes = vgui.Create("SCP.Button", p)
	yes:SetSize(UI.S(170), UI.S(36))
	yes:SetPos(UI.S(18), UI.S(100))
	yes:SetPrimary(true)
	yes:SetLabel("Принять")
	yes:SetIcon("check")
	yes.DoClick = function() answer(inv, true) end
	local no = vgui.Create("SCP.Button", p)
	no:SetSize(UI.S(170), UI.S(36))
	no:SetPos(UI.S(200), UI.S(100))
	no:SetLabel("Отклонить")
	no.DoClick = function() answer(inv, false) end
end)

-- Уберём карточки, если ушли на задание
hook.Add("Think", "scp.lobby.invites", function()
	if #L.Invites == 0 then return end
	if SCP.MyState() == "playing" then
		for i = #L.Invites, 1, -1 do answer(L.Invites[i], false) end
	end
end)
