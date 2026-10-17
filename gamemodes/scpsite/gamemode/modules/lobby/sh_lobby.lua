--[[
	Лобби отряда. Сервер хранит список, клиенту приходит его лобби: id, лидер, глава, участники.
	Фракция игрока (охрана / МОГ) задаётся главой лобби; модель запоминается отдельно для каждой фракции.
]]

local L = SCP.Lobby
L.Mine = L.Mine or nil -- на клиенте: { id, leader, chapter, members = {ply...}, started }

function L.FactionOf(ply)
	local f = ply:GetNW2String("scp.faction", "security")
	return SCP.Config.Factions[f] and f or "security", SCP.Config.Factions[f] or SCP.Config.Factions.security
end

-- Модель игрока в его текущей фракции: путь, индекс, таблица фракции
function L.ModelOf(ply)
	local fid, fac = L.FactionOf(ply)
	local i = math.Clamp(ply:GetNW2Int("scp.model." .. fid, 1), 1, #fac.models)
	return fac.models[i], i, fac
end

CreateConVar("scp_solo_kick", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Одиночная игра отключает остальных игроков")
