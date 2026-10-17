--[[
	Общее про SCP: по энтити — ключ ("096"/"173"/"049") и описание из конфига.
]]

function SCP.SCPKeyOf(ent)
	if not IsValid(ent) then return nil end
	local k = ent:GetNW2String("scp.key", "")
	if k ~= "" then return k end
	local cls = ent:GetClass()
	for key, def in pairs(SCP.Config.SCPs) do if def.class == cls then return key end end
end

-- Список активных SCP рядом (на клиенте — по энтити в мире)
function SCP.FindSCPs()
	local out = {}
	for key, def in pairs(SCP.Config.SCPs) do
		for _, e in ipairs(ents.FindByClass(def.class)) do out[#out + 1] = { ent = e, key = key, def = def } end
	end
	return out
end
