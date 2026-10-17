--[[
	Статистика оперативника (хранится между заходами, показывается в личном деле — Q).
]]

local S = SCP.Stats

function S.Add(ply, key, n)
	if not IsValid(ply) or ply:IsBot() then return end
	local st = SCP.Data.Of(ply).stats
	st[key] = (st[key] or 0) + (n or 1)
	SCP.Data.SaveSoon(ply)
end

function S.Of(ply)
	return SCP.Data.Of(ply).stats
end

net.Receive("scp.stats.req", function(_, ply)
	if (ply.scpStatsReq or 0) > CurTime() then return end
	ply.scpStatsReq = CurTime() + 0.5
	local st = table.Copy(S.Of(ply))
	st.playtime = (st.playtime or 0)
	net.Start("scp.stats")
	net.WriteTable(st)
	net.Send(ply)
end)

-- Время на задании и пройденное расстояние
timer.Create("scp.stats.tick", 5, 0, function()
	for _, p in ipairs(player.GetAll()) do
		if p:InGame() and p:Alive() then
			S.Add(p, "playtime", 5)
			local pos = p:GetPos()
			if p.scpLastPos then
				local d = pos:Distance(p.scpLastPos)
				if d < 1500 then S.Add(p, "distance", d / 52.5) end
			end
			p.scpLastPos = pos
		else
			p.scpLastPos = nil
		end
	end
end)
