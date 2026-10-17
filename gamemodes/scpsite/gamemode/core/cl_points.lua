--[[
	Точки на клиенте (нужны камерам меню и маркерам редактора).
]]

local P = SCP.Points

net.Receive("scp.points", function()
	P.Data = {}
	for _ = 1, net.ReadUInt(8) do
		local id = net.ReadString()
		local list = {}
		for _ = 1, net.ReadUInt(8) do
			list[#list + 1] = { pos = net.ReadVector(), ang = net.ReadAngle() }
		end
		P.Data[id] = list
	end
	hook.Run("SCP.PointsUpdated")
end)
