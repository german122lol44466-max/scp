--[[
	Уведомления игроку: SCP.Notify(ply|nil, текст, тип) — тип: "info" | "ok" | "warn" | "error".
]]

function SCP.Notify(ply, text, kind)
	net.Start("scp.notify")
	net.WriteString(text)
	net.WriteString(kind or "info")
	if ply then net.Send(ply) else net.Broadcast() end
end

-- Затемнение экрана у игроков (fadeIn, держим, fadeOut).
function SCP.Fade(plys, inT, hold, outT)
	net.Start("scp.fade")
	net.WriteFloat(inT or 0.6)
	net.WriteFloat(hold or 0.4)
	net.WriteFloat(outT or 0.8)
	net.Send(plys)
end
