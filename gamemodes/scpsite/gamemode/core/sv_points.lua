--[[
	Сохранение и раздача точек. Сеть: scp.points — все точки (клиентам нужны камеры меню и маркеры редактора).
]]

local P = SCP.Points

local function path()
	return "scpsite/points/" .. game.GetMap() .. ".json"
end

function P.Load()
	P.Data = {}
	local raw = file.Read(path(), "DATA")
	local t = raw and util.JSONToTable(raw) or {}
	for id, list in pairs(t) do
		P.Data[id] = {}
		for _, p in ipairs(list) do
			P.Data[id][#P.Data[id] + 1] = {
				pos = Vector(p.x or 0, p.y or 0, p.z or 0),
				ang = Angle(p.p or 0, p.yaw or 0, 0),
			}
		end
	end
end

function P.Save()
	file.CreateDir("scpsite/points")
	local t = {}
	for id, list in pairs(P.Data) do
		t[id] = {}
		for _, p in ipairs(list) do
			t[id][#t[id] + 1] = { x = math.Round(p.pos.x, 1), y = math.Round(p.pos.y, 1), z = math.Round(p.pos.z, 1),
				p = math.Round(p.ang.p, 1), yaw = math.Round(p.ang.y, 1) }
		end
	end
	file.Write(path(), util.TableToJSON(t, true))
end

function P.Send(target)
	net.Start("scp.points")
	net.WriteUInt(#P.Types, 8)
	for _, t in ipairs(P.Types) do
		local list = P.Data[t.id] or {}
		net.WriteString(t.id)
		net.WriteUInt(#list, 8)
		for _, p in ipairs(list) do
			net.WriteVector(p.pos)
			net.WriteAngle(p.ang)
		end
	end
	if target then net.Send(target) else net.Broadcast() end
end

function P.Add(id, pos, ang)
	local t = P.ByID[id]
	if not t then return false end
	P.Data[id] = P.Data[id] or {}
	if t.single then P.Data[id] = {} end
	P.Data[id][#P.Data[id] + 1] = { pos = pos, ang = ang }
	P.Save()
	P.Send()
	return true
end

function P.RemoveNear(id, pos, radius)
	local list = P.Data[id]
	if not list then return false end
	local best, bestD
	for i, p in ipairs(list) do
		local d = p.pos:DistToSqr(pos)
		if not bestD or d < bestD then best, bestD = i, d end
	end
	if best and bestD <= (radius or 200) ^ 2 then
		table.remove(list, best)
		P.Save()
		P.Send()
		return true
	end
	return false
end

function P.Clear(id)
	P.Data[id] = {}
	P.Save()
	P.Send()
end

hook.Add("Initialize", "scp.points", P.Load)
hook.Add("PlayerInitialSpawn", "scp.points", function(ply)
	timer.Simple(1, function() if IsValid(ply) then P.Send(ply) end end)
end)
