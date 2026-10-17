--[[
	Наклон (выглядывание): клиент присылает значение -1..1, остальные видят наклон корпуса.
]]

net.Receive("scp.lean", function(_, ply)
	local v = math.Clamp(net.ReadInt(8) / 100, -1, 1)
	if not ply:InGame() or not ply:Alive() then v = 0 end
	ply:SetNW2Float("scp.lean", v)
end)
