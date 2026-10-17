--[[
	Данные игрока между заходами: имя, модель, статистика.
	data/scpsite/players/<SteamID64>.json — пишется при изменении (с задержкой) и при выходе.
]]

local D = SCP.Data
D.Cache = D.Cache or {}

local function path(ply)
	return "scpsite/players/" .. ply:SteamID64() .. ".json"
end

function D.Load(ply)
	local raw = file.Read(path(ply), "DATA")
	local t = raw and util.JSONToTable(raw) or {}
	t.stats = t.stats or {}
	D.Cache[ply] = t
	return t
end

function D.Of(ply)
	return D.Cache[ply] or D.Load(ply)
end

function D.Save(ply)
	local t = D.Cache[ply]
	if not t or ply:IsBot() then return end
	file.CreateDir("scpsite/players")
	file.Write(path(ply), util.TableToJSON(t))
end

function D.SaveSoon(ply)
	timer.Create("scp.data." .. ply:EntIndex(), 3, 1, function()
		if IsValid(ply) then D.Save(ply) end
	end)
end

function D.Get(ply, key, default)
	local v = D.Of(ply)[key]
	if v == nil then return default end
	return v
end

function D.Set(ply, key, value)
	D.Of(ply)[key] = value
	D.SaveSoon(ply)
end

hook.Add("PlayerDisconnected", "scp.data", function(ply)
	D.Save(ply)
	D.Cache[ply] = nil
end)

hook.Add("ShutDown", "scp.data", function()
	for ply in pairs(D.Cache) do if IsValid(ply) then D.Save(ply) end end
end)
