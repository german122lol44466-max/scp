--[[
	Статистика на клиенте: SCP.Stats.Mine обновляется по запросу (при открытии личного дела).
]]

local S = SCP.Stats
S.Mine = S.Mine or {}

net.Receive("scp.stats", function()
	S.Mine = net.ReadTable()
end)

function S.Request()
	net.Start("scp.stats.req")
	net.SendToServer()
end
