--[[
	Катсцены на сервере: заморозить игроков, показать пролёт камеры, по окончании — продолжить сюжет.
	Пропуск: все зрители нажали пробел.
	Камеры катсцены — точки "cs_<id>" (редактор, по взгляду, по порядку). Меньше двух точек — катсцена пропускается.
]]

local CS = {}
SCP.Cutscene = CS
local cur

local function finish()
	if not cur then return end
	local c = cur
	cur = nil
	SCP.Story.InCutscene = false
	timer.Remove("scp.cutscene")
	for _, p in ipairs(c.plys) do
		if IsValid(p) then
			p:Freeze(false)
			p:GodDisable()
		end
	end
	if c.done then c.done() end
end

function CS.Play(plys, id, done)
	local def = SCP.Story.Cutscenes[id]
	if not def or SCP.Points.Count("cs_" .. id) < 2 then
		if done then done() end
		return
	end
	finish()
	cur = { id = id, plys = plys, done = done, skip = {} }
	SCP.Story.InCutscene = true
	for _, p in ipairs(plys) do
		if IsValid(p) then
			p:Freeze(true)
			p:GodEnable()
		end
	end
	net.Start("scp.cutscene")
	net.WriteString(id)
	net.Send(plys)
	timer.Create("scp.cutscene", def.duration + 1.2, 1, finish)
end

net.Receive("scp.cutscene.skip", function(_, ply)
	if not cur then return end
	cur.skip[ply] = true
	local all = true
	for _, p in ipairs(cur.plys) do
		if IsValid(p) and not cur.skip[p] then all = false break end
	end
	if all then
		net.Start("scp.cutscene")
		net.WriteString("")
		net.Send(cur.plys)
		finish()
	end
end)

concommand.Add("scp_cutscene", function(ply, _, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if IsValid(ply) then CS.Play({ ply }, args[1] or "") end
end)
