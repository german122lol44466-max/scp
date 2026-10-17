--[[
	Лобби отряда. Сервер хранит список, клиенту приходит его лобби: id, лидер, участники.
]]

local L = SCP.Lobby
L.Mine = L.Mine or nil -- на клиенте: { id, leader, members = {ply...}, started }

function L.ModelOf(ply)
	local i = math.Clamp(ply:GetNW2Int("scp.model", 1), 1, #SCP.Config.Models)
	return SCP.Config.Models[i], i
end

CreateConVar("scp_solo_kick", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Одиночная игра отключает остальных игроков")
