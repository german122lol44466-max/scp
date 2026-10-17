--[[
	Режим редактора: scp_edit (суперадмин или хост локального сервера).
	Меню, лобби и сюжет игнорируются — вы на карте, с noclip, физганом и тулганом.
	Точки ставятся из панели (зажать C) или командами:
	  scp_point <тип> add | remove | clear      — scp_points — список
	Повторный scp_edit — выход обратно в главное меню.
]]

local P = SCP.Points

local function allowed(ply)
	if not IsValid(ply) then return true end -- серверная консоль
	return ply:IsSuperAdmin() or ply:IsListenServerHost()
end

function SCP.SetEdit(ply, on)
	ply:SetNW2Bool("scp.edit", on)
	if on then
		if SCP.Lobby.Leave then SCP.Lobby.Leave(ply, true) end
		ply:SetNW2String("scp.state", "edit")
		ply:Spawn()
		timer.Simple(0, function()
			if not IsValid(ply) then return end
			ply:StripWeapons()
			ply:Give("weapon_physgun")
			ply:Give("gmod_tool")
			for _, w in ipairs(SCP.Config.Weapons) do ply:Give(w) end
			ply:SetMoveType(MOVETYPE_NOCLIP)
			ply:GodEnable()
		end)
		SCP.Notify(ply, "Редактор включён. Зажмите C — панель точек. scp_edit — выйти.", "ok")
	else
		ply:GodDisable()
		SCP.Menu.ToMenu(ply)
		SCP.Notify(ply, "Редактор выключен.", "info")
	end
	net.Start("scp.edit")
	net.WriteBool(on)
	net.Send(ply)
end

concommand.Add("scp_edit", function(ply)
	if not IsValid(ply) then print("scp_edit: только из игры") return end
	if not allowed(ply) then SCP.Notify(ply, "Редактор доступен только суперадминам.", "error") return end
	SCP.SetEdit(ply, not SCP.InEdit(ply))
end)

-- Где ставить точку: для камер — глаза и взгляд, для остального — ноги и поворот.
local function placeOf(ply, t)
	if t.cam then return ply:EyePos(), ply:EyeAngles() end
	return ply:GetPos() + Vector(0, 0, 2), Angle(0, ply:EyeAngles().y, 0)
end

local function act(ply, id, action)
	local t = P.ByID[id]
	if not t then SCP.Notify(ply, "Нет такого типа точки: " .. tostring(id), "error") return end
	if action == "add" then
		P.Add(id, placeOf(ply, t))
		SCP.Notify(ply, t.name .. ": " .. (t.single and "установлена" or ("добавлена, всего " .. P.Count(id))), "ok")
	elseif action == "remove" then
		if P.RemoveNear(id, ply:GetPos(), 300) then
			SCP.Notify(ply, t.name .. ": ближайшая удалена", "info")
		else
			SCP.Notify(ply, t.name .. ": рядом (3 м) нет точки", "warn")
		end
	elseif action == "clear" then
		P.Clear(id)
		SCP.Notify(ply, t.name .. ": все удалены", "info")
	elseif action == "tp" then
		local p = P.First(id)
		if p then
			ply:SetPos(t.cam and (p.pos - Vector(0, 0, 64)) or p.pos)
			ply:SetEyeAngles(p.ang)
		end
	end
end

net.Receive("scp.edit.act", function(_, ply)
	local id, action = net.ReadString(), net.ReadString()
	if not SCP.InEdit(ply) or not allowed(ply) then return end
	act(ply, id, action)
end)

concommand.Add("scp_point", function(ply, _, args)
	if not allowed(ply) or not IsValid(ply) then return end
	act(ply, args[1], args[2] or "add")
end)

concommand.Add("scp_points", function(ply)
	if not allowed(ply) then return end
	local lines = {}
	for _, t in ipairs(P.Types) do
		lines[#lines + 1] = string.format("%-14s %-36s %d%s", t.id, t.name, P.Count(t.id), t.need and (" / нужно " .. t.need) or "")
	end
	local text = table.concat(lines, "\n")
	if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
end)

-- В редакторе разрешено всё, что обычно запрещено режимом.
hook.Add("PlayerNoClip", "scp.edit", function(ply, on)
	if SCP.InEdit(ply) then return true end
end)

hook.Add("PlayerDisconnected", "scp.edit", function(ply) ply:SetNW2Bool("scp.edit", false) end)
